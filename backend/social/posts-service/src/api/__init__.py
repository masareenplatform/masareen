"""social-service API — posts, likes, comments and bookmarks.

Routed by the gateway under ``/api/v1`` (router prefix ``/posts``), so the
external paths are ``/api/v1/posts``, ``/api/v1/posts/{id}/like``, etc.
All payloads are wrapped in the standard ``{"success": true, "data": ...}``
envelope the gateway and frontends expect.
"""
from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from shared.dtos import ApiResponse

from ..db import get_session
from ..schemas import CommentRequest, CreatePostRequest
from ..security import get_current_user
from .. import service

router = APIRouter(prefix="/posts", tags=["Posts"])


@router.get("", response_model=ApiResponse[list])
async def get_feed(
    author_id: str | None = Query(None),
    kind: str | None = Query(None),
    limit: int = Query(40, ge=1, le=100),
    offset: int = Query(0, ge=0),
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    posts = await service.list_posts(
        session, author_id=author_id, kind=kind, user_id=token.sub, limit=limit, offset=offset
    )
    return ApiResponse.ok(posts)


@router.post("", response_model=ApiResponse[dict], status_code=201)
async def create_post(
    body: CreatePostRequest,
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    post = await service.create_post(session, token, body)
    asyncio.create_task(service.publish_event("post:new", post))
    return ApiResponse.ok(post)


@router.get("/saved", response_model=ApiResponse[list])
async def get_saved(
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    posts = await service.list_saved(session, token.sub)
    return ApiResponse.ok(posts)


@router.get("/{post_id}", response_model=ApiResponse[dict])
async def get_one(
    post_id: str,
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    post = await service.get_post(session, post_id, user_id=token.sub)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    return ApiResponse.ok(post)


@router.post("/{post_id}/like", response_model=ApiResponse[dict])
async def like_post(
    post_id: str,
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    result = await service.toggle_like(session, post_id, token.sub)
    if not result:
        raise HTTPException(status_code=404, detail="Post not found")
    asyncio.create_task(
        service.publish_event("post:react", {"postId": post_id, **result})
    )
    return ApiResponse.ok(result)


@router.post("/{post_id}/comment", response_model=ApiResponse[dict])
async def comment_post(
    post_id: str,
    body: CommentRequest,
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    comment = await service.add_comment(session, post_id, token.sub, body.text)
    if not comment:
        raise HTTPException(status_code=404, detail="Post not found")
    asyncio.create_task(
        service.publish_event("post:comment", {"postId": post_id, "comment": comment})
    )
    return ApiResponse.ok(comment)


@router.post("/{post_id}/save", response_model=ApiResponse[dict])
async def save_post(
    post_id: str,
    token=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    result = await service.toggle_save(session, post_id, token.sub)
    asyncio.create_task(
        service.publish_event("post:saved", {"postId": post_id, **result})
    )
    return ApiResponse.ok(result)
