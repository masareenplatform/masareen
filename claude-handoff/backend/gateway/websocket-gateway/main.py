"""
WebSocket Gateway for real-time updates in MASAREN.
Consumes Kafka events and pushes them to connected clients.
"""
import asyncio
import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import Dict, List
from shared.utils.kafka_consumer import KafkaConsumerBase

app = FastAPI(title="MASAREN WebSocket Gateway")

class ConnectionManager:
    def __init__(self):
        # Map user_id -> list of active WebSockets
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, user_id: str, message: dict):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_json(message)

    async def broadcast(self, message: dict):
        for user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_json(message)

manager = ConnectionManager()

class RealtimeEventConsumer(KafkaConsumerBase):
    """
    Listens to Kafka events and pushes them to the WebSocket manager.
    """
    async def handle_event(self, event: dict):
        topic = event.get("topic", "")
        payload = event.get("payload", {})
        user_id = payload.get("user_id")

        # Construct a client-friendly update message
        update = {
            "type": topic,
            "data": payload,
            "timestamp": payload.get("created_at", "")
        }

        if user_id:
            await manager.send_personal_message(user_id, update)
        
        # Broadcast global announcements or platform posts
        if topic == "masaren.platform.announcement":
            await manager.broadcast(update)

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(user_id, websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)

async def start_websocket_consumer():
    consumer = RealtimeEventConsumer(bootstrap_servers="localhost:9092")
    await consumer.start([
        "masaren.execution.evidence_verified",
        "masaren.identity.user_updated",
        "masaren.marketplace.opportunity_matched",
        "masaren.platform.announcement"
    ])

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(start_websocket_consumer())
