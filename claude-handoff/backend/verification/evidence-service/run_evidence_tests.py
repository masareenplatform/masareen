#!/usr/bin/env python3
"""Evidence Service test runner - fixed for Windows encoding."""

import subprocess
import time
import sys
import os

def run_unit_tests():
    """Run unit tests and return result."""
    print("Running unit tests...")
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pytest", "tests/unit/", "-v"],
            capture_output=True,
            text=True,
            encoding='utf-8'
        )
        print(f"Unit tests completed: {result.returncode}")
        print(result.stdout[-500:] if len(result.stdout) > 500 else result.stdout)
        return result.returncode == 0
    except Exception as e:
        print(f"Error running unit tests: {e}")
        return False

def test_api_endpoints():
    """Test Evidence API endpoints."""
    print("Testing API endpoints...")
    try:
        # Run a simple test using HTTP requests
        import requests
        
        # Test health endpoint
        try:
            response = requests.get("http://localhost:8000/health", timeout=5)
            print(f"Health endpoint: status={response.status_code}")
        except:
            print("Health endpoint failed")
            return False
            
        # Test evidence capture
        import json
        capture_payload = {
            "task_id": "task-test-123",
            "submitted_by": "user-test-456",
            "media_type": "PHOTO",
            "file_size_bytes": 2048000
        }
        
        response = requests.post("http://localhost:8000/", json=capture_payload, timeout=5)
        if response.status_code not in [200, 201]:
            print(f"Evidence capture failed: status={response.status_code}")
            return False
            
        evidence_id = response.json().get("data", {}).get("evidence_id", "test-evidence")
        print(f"Evidence captured: id={evidence_id}")
        
        # Test upload complete
        upload_payload = {
            "storage_url": "https://bucket.s3.amazonaws.com/evidence-test.jpg",
            "checksum": "a1b2c3d4e5f6"
        }
        
        response = requests.patch(f"http://localhost:8000/{evidence_id}/upload-complete", 
                                json=upload_payload, timeout=5)
        if response.status_code != 200:
            print(f"Upload complete failed: status={response.status_code}")
            return False
            
        print(f"Upload completed")
        
        # Test verification
        verify_payload = {
            "verifier_type": "AI",
            "verdict": "APPROVED",
            "confidence": 0.95,
            "verifier_id": "test-verifier-001"
        }
        
        response = requests.post(f"http://localhost:8000/{evidence_id}/verify",
                               json=verify_payload, timeout=5)
        if response.status_code != 200:
            print(f"Verification failed: status={response.status_code}")
            return False
            
        print(f"Verification completed")
        
        # Test get evidence
        response = requests.get(f"http://localhost:8000/{evidence_id}", timeout=5)
        if response.status_code != 200:
            print(f"Get evidence failed: status={response.status_code}")
            return False
            
        print(f"Evidence retrieved")
        
        # Test task listing
        response = requests.get(f"http://localhost:8000/task/task-test-123", timeout=5)
        if response.status_code != 200:
            print(f"Task listing failed: status={response.status_code}")
            return False
            
        print(f"Task listing retrieved")
        
        return True
        
    except Exception as e:
        print(f"API test error: {e}")
        return False

def main():
    """Main test runner."""
    print("EVIDENCE SERVICE VALIDATION")
    print("=" * 60)
    
    # Test 1: Unit tests
    print("\n1. Running unit tests...")
    unit_tests_passed = run_unit_tests()
    if not unit_tests_passed:
        print("Unit tests FAILED")
        sys.exit(1)
    
    # Test 2: Runtime verification
    print("\n2. Starting service for API tests...")
    try:
        process = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "src.main:app",
             "--reload", "--host", "0.0.0.0", "--port", "8000"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding='utf-8',
            errors='replace'
        )
        time.sleep(5)
        
        if process.poll() is not None:
            stdout, stderr = process.communicate()
            print(f"Service failed to start")
            print(f"STDOUT: {stdout[:500] if stdout else 'None'}")
            print(f"STDERR: {stderr[:500] if stderr else 'None'}")
            sys.exit(1)
            
        api_passed = test_api_endpoints()
        
        # Stop service
        process.terminate()
        process.wait()
        
        if not api_passed:
            print("API tests FAILED")
            sys.exit(1)
            
    except Exception as e:
        print(f"API test setup error: {e}")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED")
    print("Evidence Service satisfies Definition of Done")
    print("=" * 60)
    
    # Generate documentation
    print("\nGenerating documentation...")
    # We'll generate a summary report
    report = """
EVIDENCE SERVICE VALIDATION REPORT
==================================
Date: 2026-07-05
Objective: Prove Evidence Service satisfies Definition of Done

Test Results:
- Unit Tests: PASSED
- API Tests: PASSED

Status: COMPLETE
Ready for next service in roadmap.
"""
    
    with open("EVIDENCE_SERVICE_VALIDATION.md", "w") as f:
        f.write(report)
    print("Documentation written to EVIDENCE_SERVICE_VALIDATION.md")
    
if __name__ == "__main__":
    main()