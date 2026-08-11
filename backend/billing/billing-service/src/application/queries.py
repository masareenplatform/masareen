from dataclasses import dataclass
from shared.utils.cqrs import Query

@dataclass
class GetInvoiceQuery(Query):
    invoice_id: str

@dataclass
class ListOrgInvoicesQuery(Query):
    org_id: str
    limit: int
