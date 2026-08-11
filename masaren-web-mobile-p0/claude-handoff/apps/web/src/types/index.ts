export interface User {
  id: string; email: string; full_name: string;
  role: "INDIVIDUAL"|"ORGANIZATION"|"ADMIN"|"SUPER_ADMIN";
  status: string; pms_score: number; email_verified: boolean;
}
export interface Task {
  id: string; program_id: string; title: string;
  status: "PENDING"|"ASSIGNED"|"IN_PROGRESS"|"SUBMITTED"|"VERIFIED"|"COMPLETED"|"CANCELLED";
  priority: "LOW"|"MEDIUM"|"HIGH"|"URGENT";
  assignee_id?: string; due_date?: string;
  evidence_required: boolean; evidence_ids: string[];
}
export interface Program {
  id: string; title: string; organization_id: string; status: string;
  sdg_goals: number[]; enrolled_count: number;
}
export interface Opportunity {
  id: string; title: string;
  opp_type: "JOB"|"FUNDING"|"SCHOLARSHIP"|"RESEARCH"|"CONSULTING"|"VOLUNTEER";
  status: string; min_pms_score: number; required_skills: string[];
}
export interface ImpactPassport {
  user_id: string; full_name: string; pms_score: number;
  tier: "BRONZE"|"SILVER"|"GOLD"|"PLATINUM"; passport_id: string;
}
export interface ApiResponse<T> {
  success: boolean; data?: T; message?: string; errors?: string[];
}
