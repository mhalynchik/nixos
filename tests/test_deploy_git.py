"""Read-only Git ownership regression and non-executing rebuild command checks."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


class DeployOwnershipTests(unittest.TestCase):
    def test_trust_is_scoped_to_explicit_target(self):
        env=dict(os.environ,GIT_TEST_ASSUME_DIFFERENT_OWNER='1')
        denied=subprocess.run(['git','-C',str(ROOT),'rev-parse','--show-toplevel'],env=env,text=True,capture_output=True)
        self.assertNotEqual(denied.returncode,0)
        self.assertIn('dubious ownership',denied.stderr)
        trusted=subprocess.run(['bash','-c','source "$1/bin/lib.sh"; target_git "$1" rev-parse --show-toplevel','bash',str(ROOT)],env=env,text=True,capture_output=True)
        self.assertEqual(trusted.returncode,0,trusted.stderr)
        self.assertEqual(trusted.stdout.strip(),str(ROOT))
        denied_again=subprocess.run(['git','-C',str(ROOT),'rev-parse','--show-toplevel'],env=env,text=True,capture_output=True)
        self.assertNotEqual(denied_again.returncode,0)

    def test_rebuild_and_install_use_explicit_path_without_changing_global_git(self):
        with tempfile.TemporaryDirectory(prefix='deploy target ') as directory:
            script='''source "$1/bin/lib.sh"
            sudo() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$@"; }
            mountpoint() { return 0; }
            rebuild_flake "$2" build
            install_flake "$2"
            '''
            result=subprocess.run(['bash','-c',script,'bash',str(ROOT),directory],text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            commands=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('[')]
            self.assertEqual(commands,[['nixos-rebuild','build','--flake','path:'+directory+'#default','--impure'],['nixos-install','--flake','path:'+directory+'#default','--impure']])
