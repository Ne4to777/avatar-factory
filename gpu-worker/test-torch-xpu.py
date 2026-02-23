#!/usr/bin/env python
"""Test torch.xpu stub with real torch"""

import sys

try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    print(f"Has xpu: {hasattr(torch, 'xpu')}")
    
    # Add stub if missing
    if not hasattr(torch, 'xpu'):
        print("\nAdding XPU stub...")
        
        class XPUStub:
            def is_available(self):
                return False
            
            def device_count(self):
                return 0
            
            def __getattr__(self, name):
                def noop(*args, **kwargs):
                    return None
                return noop
        
        torch.xpu = XPUStub()
        print("✓ Stub added")
    
    # Test
    print("\nTesting torch.xpu methods:")
    print(f"  torch.xpu.is_available(): {torch.xpu.is_available()}")
    print(f"  torch.xpu.device_count(): {torch.xpu.device_count()}")
    print(f"  torch.xpu.empty_cache(): {torch.xpu.empty_cache()}")
    print(f"  torch.xpu.manual_seed(42): {torch.xpu.manual_seed(42)}")
    
    print("\n✓ All torch.xpu methods work!")
    
except ImportError:
    print("PyTorch not installed (expected on Mac)")
    sys.exit(0)
