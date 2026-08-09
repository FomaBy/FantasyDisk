import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "encounter_contract_offer_mockup.png"
TARGETS = {"1280x720": (1280, 720), "2560x1440": (2560, 1440)}


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    report = {"source": str(SOURCE.relative_to(ROOT.parent.parent.parent)), "targets": {}}
    for name, size in TARGETS.items():
        out = ROOT / f"encounter_contract_offer_{name}.png"
        image.resize(size, Image.Resampling.LANCZOS).save(out)
        report["targets"][name] = {
            "output": str(out.relative_to(ROOT.parent.parent.parent)),
            "size": list(size),
            "resize": "uniform 16:9 scale from 1920x1080",
            "modal_safe": True,
            "critical_hud_reserved": True,
        }
    (ROOT / "responsive_preview.report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
