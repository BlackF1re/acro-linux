"""Build preparation must reject divergence without editing kernel sources."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class KernelSourceCheckTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dts = self.root / 'arch/arm/boot/dts/qcom'
        self.dts.mkdir(parents=True)
        for name in ('qcom-msm8260-sony-hikari.dts',
                     'qcom-msm8260-sony-hikari-hardware.dtsi',
                     'qcom-msm8260-sony-hikari-wireless.dtsi',
                     'qcom-msm8260-sony-hikari-gpu-base.dtsi'):
            shutil.copyfile(REPO / 'kernel/dts' / name, self.dts / name)
        self.binding = self.root / 'Documentation/devicetree/bindings/arm/qcom.yaml'
        self.binding.parent.mkdir(parents=True)
        self.binding.write_text('- sony,hikari\n')
        (self.dts / 'qcom-msm8660.dtsi').write_text(
            'memory@0 {\nsleep_clk: sleep-clk {\nclocks = <&sleep_clk>;\n'
            'clock-names = "sleep";\namba-bus {\n')
        (self.dts / 'Makefile').write_text('dtb-y += qcom-msm8260-sony-hikari.dtb\n')

    def digest(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()}

    def run_check(self):
        before = self.digest()
        result = subprocess.run([str(REPO / 'scripts/prepare-hikari-kernel-tree.sh'),
                                 str(self.root)], capture_output=True, text=True)
        self.assertEqual(before, self.digest(), 'source validator modified a file')
        return result

    def test_matching_sources_are_read_only(self):
        self.assertEqual(0, self.run_check().returncode)

    def test_changed_board_is_rejected_not_overwritten(self):
        (self.dts / 'qcom-msm8260-sony-hikari.dts').write_text('different board\n')
        self.assertNotEqual(0, self.run_check().returncode)

    def test_missing_prerequisite_is_rejected_not_patched(self):
        self.binding.write_text('no Hikari binding\n')
        self.assertNotEqual(0, self.run_check().returncode)

    def test_obsolete_profile_is_rejected_not_deleted(self):
        (self.dts / 'qcom-msm8260-sony-hikari-safe.dts').write_text('historical source\n')
        self.assertNotEqual(0, self.run_check().returncode)


if __name__ == '__main__':
    unittest.main()
