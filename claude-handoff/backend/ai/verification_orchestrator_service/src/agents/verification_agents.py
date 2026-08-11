from __future__ import annotations

from ..tools.bff_tool import MasarenBffTool
import os
from ...config import settings


def _ChatGoogleGenerativeAI(*args, **kwargs):  # lazy import of optional dep
    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(*args, **kwargs)


def _Agent():  # lazy import of the optional crewai dependency
    from crewai import Agent as _CrewAgent
    return _CrewAgent

class VerificationAgents:
    def __init__(self):
        # Use the requested Gemma 4 31B IT model
        self.llm = _ChatGoogleGenerativeAI(
            model="gemma-4-31b-it",
            google_api_key=os.getenv("GOOGLE_API_KEY"),
            temperature=0.1
        )
        self.bff_tool = MasarenBffTool()

    def fraud_auditor_agent(self) -> Agent:
        return _Agent(
            role="Fraud Auditor Agent",
            goal="Analyze spatial-temporal and content anomalies to identify fraud risk (GPS spoofing, duplicate content, etc.)",
            backstory=(
                "You are a MASAREN security specialist. You excel at pattern recognition, "
                "detecting impossible travel scenarios, and identifying coordinated fraud patterns "
                "within geospatial and temporal datasets. Your verdict is the final word on whether "
                "an evidence submission is untrustworthy."
            ),
            tools=[self.bff_tool],
            llm=self.llm,
            verbose=True,
            allow_delegation=False,
            memory=True
        )

    def visual_integrity_agent(self) -> Agent:
        return _Agent(
            role="Visual Integrity Agent",
            goal="Verify the authenticity and contextual consistency of evidence based on visual scene descriptions and red flags.",
            backstory=(
                "You are a forensic visual analyst. You specialize in detecting digital manipulation, "
                "stock photo signatures, and context mismatches. You ensure that the visual reality "
                "described by the AI matches the expected environmental context of the program."
            ),
            tools=[self.bff_tool],
            llm=self.llm,
            verbose=True,
            allow_delegation=False,
            memory=True
        )

    def deliberation_agent(self) -> Agent:
        return _Agent(
            role="POAI Deliberation Agent",
            goal="Perform multi-inferencing deliberation. Ensure that verification results are not accepted on the first pass, but are cross-examined and refined.",
            backstory=(
                "You are the core of the Procedural Objective AI (POAI) framework. Your purpose is to "
                "prevent premature acceptance of AI verdicts. You examine the outputs of the Fraud and "
                "Visual agents, identify contradictions, challenge assumptions, and force a second "
                "pass of reasoning to ensure the final objective (accurate verification) is reached "
                "through rigorous deliberation."
            ),
            llm=self.llm,
            verbose=True,
            allow_delegation=True,
            memory=True
        )

    def reporter_agent(self) -> Agent:
        return _Agent(
            role="Verification Reporter",
            goal="Synthesize findings from specialized agents into a high-level executive summary.",
            backstory=(
                "You are a technical communications expert. Your job is to take complex, multi-faceted "
                "investigation results and distill them into a clear, professional, and actionable "
                "summary for MASAREN leadership."
            ),
            llm=self.llm,
            verbose=True,
            allow_delegation=False,
            memory=True
        )
