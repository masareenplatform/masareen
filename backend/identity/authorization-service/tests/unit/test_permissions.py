"""Unit tests for the RBAC permission model."""
import pytest
from src.domain.permission import Permission, Role, Action, build_role, ROLE_DEFINITIONS


class TestPermission:
    def test_permission_from_string(self):
        p = Permission.from_string("evidence:verify")
        assert p.resource == "evidence"
        assert p.action == Action.VERIFY

    def test_permission_str_representation(self):
        p = Permission(resource="task", action=Action.CREATE)
        assert str(p) == "task:create"

    def test_invalid_permission_string_raises(self):
        with pytest.raises(ValueError):
            Permission.from_string("invalid")


class TestRole:
    def test_role_grants_and_checks_permission(self):
        role = Role("TEST")
        perm = Permission("task", Action.CREATE)
        role.grant(perm)
        assert role.has_permission("task", Action.CREATE) is True

    def test_role_revoke_removes_permission(self):
        role = Role("TEST")
        perm = Permission("task", Action.CREATE)
        role.grant(perm)
        role.revoke(perm)
        assert role.has_permission("task", Action.CREATE) is False

    def test_role_returns_false_for_absent_permission(self):
        role = Role("TEST")
        assert role.has_permission("billing", Action.ADMIN) is False


class TestBuiltInRoles:
    def test_individual_can_create_evidence(self):
        role = build_role("INDIVIDUAL")
        assert role.has_permission("evidence", Action.CREATE) is True

    def test_individual_cannot_verify_evidence(self):
        role = build_role("INDIVIDUAL")
        assert role.has_permission("evidence", Action.VERIFY) is False

    def test_organization_can_verify_evidence(self):
        role = build_role("ORGANIZATION")
        assert role.has_permission("evidence", Action.VERIFY) is True

    def test_admin_can_delete_users(self):
        role = build_role("ADMIN")
        assert role.has_permission("user", Action.DELETE) is True

    def test_super_admin_has_system_admin(self):
        role = build_role("SUPER_ADMIN")
        assert role.has_permission("system", Action.ADMIN) is True

    def test_all_roles_have_definitions(self):
        for role_name in ["INDIVIDUAL", "ORGANIZATION", "ADMIN", "SUPER_ADMIN"]:
            role = build_role(role_name)
            assert len(role.permissions) > 0
