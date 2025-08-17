import json
import sys

out = {
    "python": sys.version,
}

try:
    import torch
    out["torch"] = {
        "version": torch.__version__,
        "compiled_cuda": getattr(torch.version, "cuda", None),
        "cuda_available": torch.cuda.is_available(),
    }
    if torch.cuda.is_available():
        out["torch"]["device_count"] = torch.cuda.device_count()
        out["torch"]["devices"] = {
            i: {
                "name": torch.cuda.get_device_name(i),
                "capability": torch.cuda.get_device_capability(i),
            }
            for i in range(torch.cuda.device_count())
        }
        # simple smoke test
        try:
            x = torch.randn(1024, device="cuda")
            y = (x @ x.T).sum().item()
            out["torch"]["smoke_ok"] = True
        except Exception as e:
            out["torch"]["smoke_ok"] = False
            out["torch"]["smoke_err"] = str(e)
except Exception as e:
    out["torch_error"] = str(e)

try:
    import ultralytics as u
    out["ultralytics"] = getattr(u, "__version__", "?")
except Exception as e:
    out["ultralytics_error"] = str(e)

try:
    import onnxruntime as ort
    out["onnxruntime"] = {
        "version": ort.__version__,
        "providers": ort.get_available_providers(),
    }
except Exception as e:
    out["onnxruntime_error"] = str(e)

print(json.dumps(out, indent=2))
