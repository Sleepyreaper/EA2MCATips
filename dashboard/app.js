(function () {
 "use strict";

 const DATA_PATH = "./data/dashboard-data.sample.json";
 const OFFLINE_STATUS_PATH = "./data/status.offline.json";
 const REAL_STATUS_SAMPLE_PATH = "./data/status.real.sample.json";

 const ui = {
 modeBanner: document.getElementById("mode-banner"),
 loadState: document.getElementById("load-state"),
 loadStateMessage: document.getElementById("load-state-message"),
 rbacScopeFilter: document.getElementById("rbac-scope-filter"),
 rbacTableBody: document.getElementById("rbac-table-body"),
 apiTableBody: document.getElementById("api-table-body"),
 billingHierarchyList: document.getElementById("billing-hierarchy-list"),
 invoiceFlowList: document.getElementById("invoice-flow-list"),
 billingNotesTableBody: document.getElementById("billing-notes-table-body"),
 statusOverview: document.getElementById("status-overview"),
 statusSteps: document.getElementById("status-steps"),
 statusWarnings: document.getElementById("status-warnings"),
 statusNextStep: document.getElementById("status-next-step"),
 summaryDocumented: document.getElementById("summary-documented"),
 summaryPartial: document.getElementById("summary-partial"),
 summaryInferred: document.getElementById("summary-inferred"),
 summaryPending: document.getElementById("summary-pending"),
 summaryMode: document.getElementById("summary-mode"),
 summaryInputValidation: document.getElementById("summary-input-validation"),
 summaryTerraformValidate: document.getElementById("summary-terraform-validate"),
 summaryLiveAuth: document.getElementById("summary-live-auth")
 };

 async function loadJson(path) {
 const response = await fetch(path, { cache: "no-store" });
 if (!response.ok) {
 throw new Error(`Failed to load ${path}: ${response.status}`);
 }
 return response.json();
 }

 async function loadStatusData() {
 try {
 return await loadJson(REAL_STATUS_SAMPLE_PATH);
 } catch (_error) {
 return loadJson(OFFLINE_STATUS_PATH);
 }
 }

 function setLoadState(kind, message) {
 if (!ui.loadState ||!ui.loadStateMessage) {
 return;
 }

 ui.loadState.className = `load-panel load-panel--${kind}`;
 ui.loadStateMessage.textContent = message;
 }

 function escapeHtml(value) {
 return String(value?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
 }

 function titleCase(value) {
 return String(value?? "").split("_").map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
 }

 function normalizeArray(value) {
 return Array.isArray(value)? value: [];
 }

 function badgeClass(status) {
 const map = {
 documented: "badge badge--documented",
 partially_documented: "badge badge--partially_documented",
 inferred: "badge badge--inferred",
 pending_validation: "badge badge--pending_validation",
 pass: "badge badge--ok",
 ok: "badge badge--ok",
 success: "badge badge--ok",
 succeeded: "badge badge--ok",
 ready: "badge badge--ok",
 warning: "badge badge--warn",
 warn: "badge badge--warn",
 pending: "badge badge--warn",
 partial: "badge badge--warn",
 not_run: "badge badge--warn",
 fail: "badge badge--fail",
 failed: "badge badge--fail",
 error: "badge badge--fail",
 blocked: "badge badge--fail",
 info: "badge badge--info"
 };
 return map[status] || "badge badge--info";
 }

 function badgeHtml(label, status) {
 return `<span class="${badgeClass(status)}">${escapeHtml(label)}</span>`;
 }

 function renderSource(meta) {
 const key = meta?.source_ref_key || "n/a";
 const linkKey = meta?.docs_link_key? ` / ${escapeHtml(meta.docs_link_key)}`: "";
 return `<span class="source-key">${escapeHtml(key)}${linkKey}</span>`;
 }

 function renderModeBanner(mode) {
 if (!ui.modeBanner) {
 return;
 }

 ui.modeBanner.classList.remove(
 "mode-banner--pending",
 "mode-banner--offline",
 "mode-banner--real"
 );

 if (mode === "offline_demo") {
 ui.modeBanner.classList.add("mode-banner--offline");
 ui.modeBanner.textContent =
 "OFFLINE DEMO — No live Azure authentication attempted. No subscription creation attempted.";
 return;
 }

 if (mode === "real_environment") {
 ui.modeBanner.classList.add("mode-banner--real");
 ui.modeBanner.textContent =
 "REAL ENVIRONMENT STATUS — Sanitized post-run data. No secrets displayed.";
 return;
 }

 ui.modeBanner.classList.add("mode-banner--pending");
 ui.modeBanner.textContent = "Dashboard mode unknown.";
 }

 function populateScopeFilter(items) {
 const scopes = Array.from(
 new Set(
 normalizeArray(items).map((item) => item.recommended_scope).filter(Boolean)
 )
 ).sort();

 scopes.forEach((scope) => {
 const option = document.createElement("option");
 option.value = scope;
 option.textContent = titleCase(scope);
 ui.rbacScopeFilter.appendChild(option);
 });
 }

 function renderRbac(items, selectedScope) {
 const filteredItems = selectedScope === "all"? normalizeArray(items): normalizeArray(items).filter((item) => item.recommended_scope === selectedScope);

 if (!filteredItems.length) {
 ui.rbacTableBody.innerHTML = `
 <tr>
 <td colspan="8">No RBAC rows match the current filter.</td>
 </tr>
 `;
 return;
 }

 ui.rbacTableBody.innerHTML = filteredItems.map((item) => {
 const supportedBy = normalizeArray(item.also_supported_by);
 return `
 <tr>
 <td>
 <strong>${escapeHtml(item.task_label)}</strong><br />
 <span class="muted">${escapeHtml(item.task_id)}</span>
 </td>
 <td>
 <strong>${escapeHtml(item.recommended_role)}</strong><br />
 <span class="muted">${escapeHtml(item.recommended_scope)}</span>
 </td>
 <td>${badgeHtml(titleCase(item.recommendation_status), item.recommendation_status)}</td>
 <td>${badgeHtml(titleCase(item.evidence_status), item.evidence_status)}</td>
 <td>
 ${supportedBy.length? `<ul class="inline-list">${supportedBy.map((role) => `<li>${escapeHtml(role)}</li>`).join("")}</ul>`: `<span class="muted">Not listed</span>`}
 </td>
 <td>${escapeHtml(item.least_privilege_reason || "Not provided")}</td>
 <td>${escapeHtml(item.uncertainty || "None noted")}</td>
 <td>${renderSource(item)}</td>
 </tr>
 `;
 }).join("");
 }

 function renderApi(items) {
 const rows = normalizeArray(items);

 if (!rows.length) {
 ui.apiTableBody.innerHTML = `
 <tr>
 <td colspan="7">No API mapping rows found.</td>
 </tr>
 `;
 return;
 }

 ui.apiTableBody.innerHTML = rows.map((item) => `
 <tr>
 <td>${escapeHtml(item.ea_concept)}</td>
 <td>${escapeHtml(item.mca_concept)}</td>
 <td>${escapeHtml(item.scope_change)}</td>
 <td>${escapeHtml(item.breaking_change)}</td>
 <td>${escapeHtml(item.migration_action)}</td>
 <td>${badgeHtml(titleCase(item.evidence_status), item.evidence_status)}</td>
 <td>${renderSource(item)}</td>
 </tr>
 `).join("");
 }

 function renderBilling(billing) {
 const hierarchyLevels = normalizeArray(billing?.hierarchy_levels);
 const flowNotes = normalizeArray(billing?.invoice_flow_notes);
 const billingNotes = normalizeArray(billing?.billing_notes);

 ui.billingHierarchyList.innerHTML = hierarchyLevels.length? hierarchyLevels.map((item) => `
 <li>
 <strong>${escapeHtml(item.level_name)}</strong> —
 ${escapeHtml(item.description)}
 <div class="muted">
 ${titleCase(item.evidence_status)} · ${escapeHtml(item.source_ref_key || "n/a")}
 </div>
 </li>
 `).join(""): "<li>No hierarchy data found.</li>";

 ui.invoiceFlowList.innerHTML = flowNotes.length? flowNotes.map((item) => `
 <li>
 ${escapeHtml(item.statement)}
 <div>
 ${badgeHtml(titleCase(item.evidence_status), item.evidence_status)}
 ${renderSource(item)}
 </div>
 </li>
 `).join(""): "<li>No invoice flow notes found.</li>";

 ui.billingNotesTableBody.innerHTML = billingNotes.length? billingNotes.map((item) => `
 <tr>
 <td>${escapeHtml(item.topic)}</td>
 <td>${escapeHtml(item.statement)}</td>
 <td>${badgeHtml(titleCase(item.evidence_status), item.evidence_status)}</td>
 <td>${renderSource(item)}</td>
 <td>${escapeHtml(item.uncertainty || "None noted")}</td>
 </tr>
 `).join(""): `
 <tr>
 <td colspan="5">No billing notes found.</td>
 </tr>
 `;
 }

 function renderStatus(status) {
 const overviewItems = [
 ["Mode", status?.mode || "Unknown"],
 ["Timestamp (UTC)", status?.timestamp_utc || "Unknown"],
 ["Input validation", status?.input_validation?.state || "Unknown"],
 ["Terraform validate", status?.terraform_validate?.state || "Unknown"],
 ["Terraform plan", status?.terraform_plan?.state || "Unknown"],
 ["Authentication", status?.authentication?.state || "Unknown"],
 ["Billing scope resolution", status?.billing_scope_resolution?.state || "Unknown"],
 ["Alias submission", status?.subscription_alias_submission?.state || "Unknown"],
 ["Creation result", status?.subscription_creation_result?.state || "Unknown"]
 ];

 ui.statusOverview.innerHTML = overviewItems.map(([label, value]) => `
 <div>
 <dt>${escapeHtml(label)}</dt>
 <dd>${badgeHtml(String(value), String(value))}</dd>
 </div>
 `).join("");

 const steps = normalizeArray(status?.steps);
 ui.statusSteps.innerHTML = steps.length? steps.map((step) => `
 <li>
 <strong>${escapeHtml(step.label)}</strong>
 <div>${badgeHtml(String(step.state), String(step.state))}</div>
 <div class="muted">${escapeHtml(step.detail || "No detail provided")}</div>
 </li>
 `).join(""): "<li>No execution steps found.</li>";

 const warnings = normalizeArray(status?.warnings);
 ui.statusWarnings.innerHTML = warnings.length? warnings.map((warning) => `<li>${escapeHtml(warning)}</li>`).join(""): "<li>No warnings recorded.</li>";

 ui.statusNextStep.textContent = `Next step: ${status?.next_step || "No next step provided."}`;

 ui.summaryMode.textContent = status?.mode || "Unknown";
 ui.summaryInputValidation.textContent = status?.input_validation?.state || "Unknown";
 ui.summaryTerraformValidate.textContent = status?.terraform_validate?.state || "Unknown";
 ui.summaryLiveAuth.textContent = status?.authentication?.state || "Unknown";

 renderModeBanner(status?.mode);
 }

 function updateEvidenceSummary(data) {
 const counts = {
 documented: 0,
 partially_documented: 0,
 inferred: 0,
 pending_validation: 0
 };

 const combined = [...normalizeArray(data?.rbac_tasks),...normalizeArray(data?.api_mapping),...normalizeArray(data?.billing?.hierarchy_levels),...normalizeArray(data?.billing?.invoice_flow_notes),...normalizeArray(data?.billing?.billing_notes)
 ];

 combined.forEach((item) => {
 if (Object.prototype.hasOwnProperty.call(counts, item.evidence_status)) {
 counts[item.evidence_status] += 1;
 }
 });

 ui.summaryDocumented.textContent = String(counts.documented);
 ui.summaryPartial.textContent = String(counts.partially_documented);
 ui.summaryInferred.textContent = String(counts.inferred);
 ui.summaryPending.textContent = String(counts.pending_validation);
 }

 function validateDashboardData(data) {
 const requiredKeys = ["metadata", "rbac_tasks", "api_mapping", "billing"];
 const missing = requiredKeys.filter((key) =>!(key in data));
 if (missing.length) {
 throw new Error(`Dashboard data missing required keys: ${missing.join(", ")}`);
 }
 }

 async function main() {
 try {
 setLoadState("info", "Loading dashboard JSON payloads…");

 const [dashboardData, statusData] = await Promise.all([
 loadJson(DATA_PATH),
 loadStatusData()
 ]);

 validateDashboardData(dashboardData);
 populateScopeFilter(dashboardData.rbac_tasks);
 renderRbac(dashboardData.rbac_tasks, "all");
 renderApi(dashboardData.api_mapping);
 renderBilling(dashboardData.billing);
 renderStatus(statusData);
 updateEvidenceSummary(dashboardData);

 ui.rbacScopeFilter.addEventListener("change", function (event) {
 renderRbac(dashboardData.rbac_tasks, event.target.value);
 });

 setLoadState(
 "success",
 "Dashboard data loaded successfully. Review evidence states and uncertainty markers before treating any recommendation as tenant-verified."
 );
 } catch (error) {
 console.error(error);
 setLoadState("error", `Dashboard failed to load local data: ${error.message}`);
 renderModeBanner("unknown");

 ui.rbacTableBody.innerHTML = `
 <tr>
 <td colspan="8">Unable to load RBAC data. Verify dashboard/data JSON files and reload.</td>
 </tr>
 `;
 ui.apiTableBody.innerHTML = `
 <tr>
 <td colspan="7">Unable to load API mapping data. Verify dashboard/data JSON files and reload.</td>
 </tr>
 `;
 ui.billingHierarchyList.innerHTML = "<li>Unable to load hierarchy data.</li>";
 ui.invoiceFlowList.innerHTML = "<li>Unable to load invoice flow data.</li>";
 ui.billingNotesTableBody.innerHTML = `
 <tr>
 <td colspan="5">Unable to load billing notes.</td>
 </tr>
 `;
 ui.statusOverview.innerHTML = `
 <div>
 <dt>Load status</dt>
 <dd>${badgeHtml("error", "fail")}</dd>
 </div>
 `;
 ui.statusSteps.innerHTML = "<li>Status data unavailable.</li>";
 ui.statusWarnings.innerHTML = `<li>${escapeHtml(error.message)}</li>`;
 ui.statusNextStep.textContent = "Next step: verify local JSON files and serve the dashboard over HTTP.";
 }
 }

 document.addEventListener("DOMContentLoaded", main);
})();
