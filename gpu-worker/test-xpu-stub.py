#!/usr/bin/env python
"""Test XPU stub logic"""

class XPUStub:
    """Universal stub for Intel XPU API"""
    
    def is_available(self):
        return False
    
    def device_count(self):
        return 0
    
    def __getattr__(self, name):
        """Catch-all for any XPU method - return no-op function"""
        def noop(*args, **kwargs):
            return None
        return noop

# Test
xpu = XPUStub()

print("Testing XPU stub:")
print(f"  is_available(): {xpu.is_available()}")
print(f"  device_count(): {xpu.device_count()}")
print(f"  empty_cache(): {xpu.empty_cache()}")
print(f"  manual_seed(42): {xpu.manual_seed(42)}")
print(f"  synchronize(): {xpu.synchronize()}")
print(f"  any_random_method(): {xpu.any_random_method()}")

print("\n✓ All methods work without errors!")
