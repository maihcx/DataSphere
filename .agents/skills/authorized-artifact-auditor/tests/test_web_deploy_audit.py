import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "web-app-scanner" / "scripts" / "deploy_audit.py"


class DeployAuditTests(unittest.TestCase):
    def run_audit(self, files, *extra_args):
        with tempfile.TemporaryDirectory() as temp_dir:
            project = Path(temp_dir) / "project"
            output = Path(temp_dir) / "report"
            project.mkdir()

            for relative_path, content in files.items():
                target = project / relative_path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content, encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    str(project),
                    "--out",
                    str(output),
                    *extra_args,
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )

            report_path = output / "findings.json"
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else None
            markdown = (
                (output / "FINDINGS.md").read_text(encoding="utf-8")
                if (output / "FINDINGS.md").exists()
                else ""
            )
            return result, report, markdown

    def test_reports_weak_deploy_secret_without_disclosing_value(self):
        leaked_value = "same-example-secret"
        result, report, markdown = self.run_audit(
            {
                ".env.example": f"APP_KEY={leaked_value}\n",
                ".env.production": f"APP_KEY={leaked_value}\nJWT_SECRET=short-token\n",
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        secret_findings = [item for item in report["findings"] if item["category"] == "secrets"]
        self.assertTrue(any(item["id"] == "ENV-EXAMPLE-VALUE" for item in secret_findings))
        self.assertTrue(any(item["id"] == "ENV-WEAK-SECRET" for item in secret_findings))
        serialized = json.dumps(report, ensure_ascii=False) + markdown + result.stdout
        self.assertNotIn(leaked_value, serialized)
        self.assertNotIn("short-token", serialized)

    def test_accepts_random_secret_with_at_least_32_characters(self):
        result, report, _ = self.run_audit(
            {".env.production": "APP_KEY=4pN7!xQ2@vL9#sD6$mK3%zR8&cW5*tY1\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(item["category"] == "secrets" for item in report["findings"]))

    def test_reports_repeating_32_character_secret_as_non_random(self):
        patterned = "0123456789abcdef0123456789abcdef"
        result, report, markdown = self.run_audit(
            {".env.production": f"APP_KEY={patterned}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        findings = [item for item in report["findings"] if item["id"] == "ENV-WEAK-SECRET"]
        self.assertTrue(findings)
        self.assertIn("repeating or predictable pattern", findings[0]["evidence"]["reasons"])
        self.assertNotIn(patterned, json.dumps(report) + markdown + result.stdout)

    def test_reports_sequential_32_character_secret_as_non_random(self):
        patterned = "abcdefghijklmnopqrstuvwxyz012345"
        result, report, markdown = self.run_audit(
            {".env.production": f"JWT_SECRET={patterned}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        findings = [item for item in report["findings"] if item["id"] == "ENV-WEAK-SECRET"]
        self.assertTrue(findings)
        self.assertIn("repeating or predictable pattern", findings[0]["evidence"]["reasons"])
        self.assertNotIn(patterned, json.dumps(report) + markdown + result.stdout)

    def test_reports_weak_password_inside_database_url_without_disclosure(self):
        database_url = "postgresql://deploy:admin123@database.internal/app"
        result, report, markdown = self.run_audit(
            {".env.production": f"DATABASE_URL={database_url}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        findings = [item for item in report["findings"] if item["id"] == "ENV-WEAK-SECRET"]
        self.assertTrue(findings)
        self.assertEqual(findings[0]["evidence"]["component"], "URL password")
        serialized = json.dumps(report) + markdown + result.stdout
        self.assertNotIn(database_url, serialized)
        self.assertNotIn("admin123", serialized)

    def test_reports_empty_password_inside_database_url(self):
        database_url = "postgresql://deploy:@database.internal/app"
        result, report, markdown = self.run_audit(
            {".env.production": f"DATABASE_URL={database_url}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        findings = [item for item in report["findings"] if item["id"] == "ENV-WEAK-SECRET"]
        self.assertTrue(findings)
        self.assertIn("empty", findings[0]["evidence"]["reasons"])
        self.assertNotIn(database_url, json.dumps(report) + markdown + result.stdout)

    def test_reports_missing_frontend_build_and_production_source_maps(self):
        missing_result, missing_report, _ = self.run_audit(
            {"package.json": '{"scripts":{"build":"vite build"}}'}
        )
        map_result, map_report, _ = self.run_audit(
            {
                "package.json": '{"scripts":{"build":"vite build"}}',
                "dist/app.js": "console.log('built');\n//# sourceMappingURL=app.js.map\n",
                "dist/app.js.map": "{}",
                "vite.config.js": "export default { build: { sourcemap: true } };\n",
            }
        )

        self.assertEqual(missing_result.returncode, 0, missing_result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-BUILD-MISSING" for item in missing_report["findings"])
        )
        self.assertEqual(map_result.returncode, 0, map_result.stderr)
        map_ids = {item["id"] for item in map_report["findings"]}
        self.assertIn("FE-SOURCEMAP-FILE", map_ids)
        self.assertIn("FE-SOURCEMAP-REFERENCE", map_ids)
        self.assertIn("FE-SOURCEMAP-ENABLED", map_ids)

    def test_reports_missing_custom_frontend_build_and_empty_output(self):
        custom_result, custom_report, _ = self.run_audit(
            {"package.json": '{"scripts":{"build":"rollup -c"}}'}
        )
        empty_result, empty_report, _ = self.run_audit(
            {
                "package.json": '{"scripts":{"build":"node scripts/build.js"}}',
                "dist/.gitkeep": "",
            }
        )

        self.assertEqual(custom_result.returncode, 0, custom_result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-BUILD-MISSING" for item in custom_report["findings"])
        )
        self.assertEqual(empty_result.returncode, 0, empty_result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-BUILD-MISSING" for item in empty_report["findings"])
        )

    def test_reports_quoted_angular_production_source_map_setting(self):
        result, report, _ = self.run_audit(
            {
                "angular.json": (
                    '{"projects":{"app":{"architect":{"build":{"configurations":'
                    '{"production":{"sourceMap":true}}}}}}}'
                )
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in report["findings"])
        )

    def test_reports_hidden_vite_and_angular_object_source_maps(self):
        vite_result, vite_report, _ = self.run_audit(
            {"vite.config.js": "export default { build: { sourcemap: 'hidden' } };\n"}
        )
        angular_result, angular_report, _ = self.run_audit(
            {
                "angular.json": (
                    '{"projects":{"app":{"architect":{"build":{"configurations":'
                    '{"production":{"sourceMap":{"scripts":true,"styles":false}}}}}}}}'
                )
            }
        )

        self.assertEqual(vite_result.returncode, 0, vite_result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in vite_report["findings"])
        )
        self.assertEqual(angular_result.returncode, 0, angular_result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in angular_report["findings"])
        )

    def test_ignores_development_only_source_maps(self):
        env_result, env_report, _ = self.run_audit(
            {".env.development": "GENERATE_SOURCEMAP=true\n"}
        )
        angular_result, angular_report, _ = self.run_audit(
            {
                "angular.json": (
                    '{"projects":{"app":{"architect":{"build":{'
                    '"configurations":{"development":{"sourceMap":true},'
                    '"production":{"sourceMap":false}}}}}}}'
                )
            }
        )

        self.assertEqual(env_result.returncode, 0, env_result.stderr)
        self.assertFalse(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in env_report["findings"])
        )
        self.assertEqual(angular_result.returncode, 0, angular_result.stderr)
        self.assertFalse(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in angular_report["findings"])
        )

    def test_reports_cra_source_map_setting_in_multiline_env(self):
        result, report, _ = self.run_audit(
            {
                ".env.production": (
                    "NODE_ENV=production\n"
                    "GENERATE_SOURCEMAP=true\n"
                    "PUBLIC_URL=/\n"
                )
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            any(item["id"] == "FE-SOURCEMAP-ENABLED" for item in report["findings"])
        )

    def test_reports_hidden_and_nosources_webpack_source_maps(self):
        result, report, _ = self.run_audit(
            {
                "webpack.config.js": "module.exports = { devtool: 'hidden-source-map' };\n",
                "webpack.config.prod.js": (
                    "module.exports = { devtool: 'nosources-source-map' };\n"
                ),
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        matches = [item for item in report["findings"] if item["id"] == "FE-SOURCEMAP-ENABLED"]
        self.assertEqual(len(matches), 2)

    def test_reports_default_admin_credentials_without_disclosing_password(self):
        password = "admin123"
        result, report, markdown = self.run_audit(
            {".env.production": f"ADMIN_USERNAME=admin\nADMIN_PASSWORD={password}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            any(item["id"] == "ADMIN-WEAK-CREDENTIAL" for item in report["findings"])
        )
        self.assertNotIn(password, json.dumps(report) + markdown + result.stdout)

    def test_reports_default_admin_pair_in_seed_config(self):
        password = "qwerty"
        result, report, markdown = self.run_audit(
            {
                "config/seed-admin.json": (
                    "{\n"
                    '  "username": "admin",\n'
                    f'  "password": "{password}"\n'
                    "}\n"
                )
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            any(item["id"] == "ADMIN-WEAK-CREDENTIAL" for item in report["findings"])
        )
        self.assertNotIn(password, json.dumps(report) + markdown + result.stdout)

    def test_ignores_runtime_admin_password_reference_in_seed_config(self):
        result, report, _ = self.run_audit(
            {
                "config/seed-admin.json": (
                    "{\n"
                    '  "username": "admin",\n'
                    '  "password": "${ADMIN_PASSWORD}"\n'
                    "}\n"
                )
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(item["category"] == "admin-auth" for item in report["findings"]))

    def test_reports_unquoted_default_admin_pair_in_yaml(self):
        password = "admin123"
        result, report, markdown = self.run_audit(
            {"config/admin.yml": f"username: admin\npassword: {password}\n"}
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(
            any(item["id"] == "ADMIN-WEAK-CREDENTIAL" for item in report["findings"])
        )
        self.assertNotIn(password, json.dumps(report) + markdown + result.stdout)

    def test_reports_static_xss_sinks_as_review_required(self):
        result, report, _ = self.run_audit(
            {
                "src/Profile.jsx": (
                    "export function Profile({ html }) {\n"
                    "  return <section dangerouslySetInnerHTML={{ __html: html }} />;\n"
                    "}\n"
                ),
                "src/legacy.js": "document.querySelector('#preview').innerHTML = location.hash;\n",
            }
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        xss_findings = [item for item in report["findings"] if item["category"] == "xss"]
        self.assertGreaterEqual(len(xss_findings), 2)
        self.assertTrue(all(item["confidence"] == "review-required" for item in xss_findings))

    def test_fail_on_high_returns_nonzero_after_writing_reports(self):
        result, report, markdown = self.run_audit(
            {".env.production": "JWT_SECRET=short\n"}, "--fail-on", "high"
        )

        self.assertEqual(result.returncode, 1)
        self.assertIsNotNone(report)
        self.assertIn("Pre-deploy Security Audit", markdown)


if __name__ == "__main__":
    unittest.main()
