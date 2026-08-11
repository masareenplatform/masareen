"""Neo4j node label definitions and schemas for MASAREN Knowledge Graph."""
from enum import Enum


class NodeLabel(str, Enum):
    PERSON = "Person"
    ORGANIZATION = "Organization"
    PROGRAM = "Program"
    TASK = "Task"
    EVIDENCE = "Evidence"
    IMPACT_ASSET = "ImpactAsset"
    CERTIFICATE = "Certificate"
    SKILL = "Skill"
    OPPORTUNITY = "Opportunity"
    FUNDING = "Funding"
    COMMUNITY = "Community"
    REGION = "Region"
    SDG = "SDG"
    REPORT = "Report"
    KNOWLEDGE_ITEM = "KnowledgeItem"


class RelationshipType(str, Enum):
    # Person → Task
    ASSIGNED_TO = "ASSIGNED_TO"
    COMPLETED = "COMPLETED"
    SUPERVISED = "SUPERVISED"
    # Person → Organization
    MEMBER_OF = "MEMBER_OF"
    EMPLOYED_BY = "EMPLOYED_BY"
    VOLUNTEERS_FOR = "VOLUNTEERS_FOR"
    # Person → Skill
    HAS_SKILL = "HAS_SKILL"
    CERTIFIED_IN = "CERTIFIED_IN"
    # Person → Opportunity
    MATCHED_TO = "MATCHED_TO"
    APPLIED_TO = "APPLIED_TO"
    # Organization → Program
    RUNS = "RUNS"
    FUNDS = "FUNDS"
    PARTNERS_WITH = "PARTNERS_WITH"
    # Program → Task
    CONTAINS = "CONTAINS"
    REQUIRES = "REQUIRES"
    # Task → Evidence
    DOCUMENTED_BY = "DOCUMENTED_BY"
    # Evidence → ImpactAsset
    GENERATED = "GENERATED"
    # Program → SDG
    CONTRIBUTES_TO = "CONTRIBUTES_TO"
    # Community → Region
    LOCATED_IN = "LOCATED_IN"
    # Generic
    BELONGS_TO = "BELONGS_TO"
    RELATED_TO = "RELATED_TO"
