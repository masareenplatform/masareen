# INVENTION DISCLOSURE FORM (IDF)

**ID:** IDF-003
**Title:** Geo-Fenced Field Verification System — Location-Locked Task Execution and Evidence Verification
**Date:** August 11, 2026
**Classification:** CONFIDENTIAL — PROPRIETARY
**Status:** 🔴 Draft

---

## 1. SUMMARY

The Geo-Fenced Field Verification System enforces location-based task execution and evidence submission within dynamically defined geographic boundaries. Using PostGIS geospatial queries, device sensor fusion, and multi-layer geofence crossing detection, the system ensures that field actions (e.g., tree planting, site inspection, community survey) are performed only within authorized geographic areas and that submitted evidence is verifiably linked to the correct location.

The system implements three layers of geofence validation:

1. **Coarse Geofence:** Polygon-based boundary check using PostGIS
2. **Fine Geofence:** Point-of-interest (POI) proximity check with radius thresholds
3. **Micro-Geofence:** Real-time trajectory validation during evidence capture

---

## 2. TECHNICAL FIELD

This invention relates to geolocation systems, geospatial databases, and mobile verification. More specifically, it relates to a method and system for:

- Enforcing location-based task execution within dynamic geographic boundaries
- Validating GPS evidence against geospatial constraints
- Detecting geofence tampering or spoofing
- Providing cryptographic proof of location for evidence submissions

---

## 3. PROBLEM STATEMENT

Prior art systems face challenges:

1. **Coarse geofencing only:** Most systems check a single GPS point against a polygon, easily defeated by spoofing or walking to the edge
2. **No real-time enforcement:** Actions can be submitted from outside the geofence post-facto
3. **No trajectory validation:** Does not verify the actor was present throughout the action
4. **No integration with evidence capture:** Location is checked separately from evidence submission

---

## 4. DETAILED DESCRIPTION

### 4.1 Geofence Definition

Geofences are defined as PostGIS polygons with optional:
- Entry/exit rules (must start inside, must finish inside)
- Time windows (valid during specific hours/days)
- Altitude constraints (for indoor/outdoor validation)
- POI proximity requirements (must be within X meters of a known point)

### 4.2 Three-Layer Validation

**Layer 1 — Coarse:**
```sql
SELECT ST_Contains(geofence_polygon, ST_SetSRID(ST_MakePoint(lon, lat), 4326))
FROM geofences WHERE id = :geofence_id
```

**Layer 2 — Fine:**
- Check distance to nearest POI within the geofence
- Radius threshold: ±10 meters for high-confidence areas
- Use PostGIS `ST_DWithin()` for proximity checks

**Layer 3 — Micro:**
- Continuous GPS monitoring during evidence capture
- Trajectory stored as a series of GeoHash points
- Minimum trajectory length required for certain action types
- Speed limit validation (walking vs. driving)

### 4.3 Anti-Spoofing Measures

- **GNSS Raw Measurement Validation:** Checks GPS signal-to-noise ratio, carrier frequency, and pseudorange variance
- **Sensor Fusion:** Combines GPS with accelerometer, gyroscope, and barometric pressure
- **Temporal Consistency:** Validates that GPS timestamps are monotonically increasing and consistent with device clock
- **Network Location Fallback:** Cross-checks against cell tower triangulation

### 4.4 Cryptographic Location Proof

On evidence submission, the system generates a cryptographic proof:

```json
{
  "proof_type": "geofence_v3",
  "geofence_id": "GF-<uuid>",
  "actor_id": "<wallet>",
  "entry_point": {"lat": 24.7, "lon": 46.5, "timestamp": "2026-08-11T10:00:00Z"},
  "exit_point": {"lat": 24.7, "lon": 46.6, "timestamp": "2026-08-11T10:15:00Z"},
  "trajectory_points": 47,
  "hash_chain_root": "<merkle-root>",
  "signature": "<actor-signature>"
}
```

### 4.5 Integration with Verification Pipeline

Geofence validation results feed directly into the Verification Pipeline (IDF-001) as the `geospatial` verification stage. A failed geofence check immediately reduces the overall verification confidence score below the 0.90 threshold.

---

## 5. INVENTOR(S)

| Name | Affiliation | Contribution |
|------|------------|--------------|
| [Geospatial Engineer] | MASAREN | PostGIS integration, polygon algorithms |
| [Mobile Engineer] | MASAREN | Android/iOS sensor fusion, GPS handling |
| [Security Engineer] | MASAREN | Anti-spoofing measures, cryptographic proofs |

---

## 6. COMMERCIAL APPLICATION

- **Environmental conservation:** Verify tree planting occurred in designated reforestation zones
- **Infrastructure inspection:** Ensure site visits occurred at exact asset locations
- **Community programs:** Confirm community leaders completed rounds in assigned neighborhoods
- **Quality assurance:** Location-locked audits and inspections
- **Insurance claims:** Verify claimants were at incident locations

---

## 7. ATTACHMENTS

1. Geofence configuration schema
2. PostGIS query optimization techniques
3. Sensor fusion algorithm pseudocode
4. GNSS anti-spoofing detection heuristics

---

**Form Completed By:** MASAREN Legal Team
**Date:** August 11, 2026
**IDF Reference:** IDF-003-20260811
**Distribution:** Legal Team, Patent Attorney, CTO, Board IP Committee