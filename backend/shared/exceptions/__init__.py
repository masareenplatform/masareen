"""Shared domain exceptions."""


class DomainException(Exception):
    """Base class for domain exceptions."""
    def __init__(self, message: str, code: str = "DOMAIN_ERROR"):
        super().__init__(message)
        self.code = code
        self.message = message


class NotFoundException(DomainException):
    def __init__(self, resource: str, id: str):
        super().__init__(f"{resource} with id '{id}' not found", "NOT_FOUND")


class ValidationException(DomainException):
    def __init__(self, message: str):
        super().__init__(message, "VALIDATION_ERROR")


class UnauthorizedException(DomainException):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(message, "UNAUTHORIZED")


class ConflictException(DomainException):
    def __init__(self, message: str):
        super().__init__(message, "CONFLICT")
