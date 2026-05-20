const DOCUMENTATION_GROUPS = [
  {
    title: "Server",
    collapsed: true,
    names: [
      "server_overview",
      "server_properties",
      "server_databases_summary",
      "server_runtime",
      "server_configurations",
      "server_services",
      "server_logins",
      "server_role_members",
      "server_endpoints",
      "linked_servers",
      "availability_groups",
    ],
  },
  {
    title: "Database",
    names: [
      "database_overview",
      "database_properties",
      "database_scoped_configurations",
      "database_extended_properties",
    ],
  },
  { title: "Storage", names: ["database_files", "filegroups", "space_usage"] },
  { title: "Structure", names: ["schemas", "tables", "columns", "indexes", "foreign_keys"] },
  { title: "Constraints", names: ["key_constraints", "check_constraints", "default_constraints"] },
  { title: "SQL Code", names: ["views", "procedures", "functions", "triggers"] },
  {
    title: "Security",
    names: ["database_principals", "database_roles", "database_role_members", "database_permissions"],
  },
  {
    title: "Jobs",
    names: ["process_inventory", "process_steps", "process_recent_runs"],
  },
  { title: "Analysis", names: ["review_findings", "index_usage", "index_physical_stats", "missing_indexes", "statistics"] },
];

const PROCESS_GROUPS = [];

const LINEAGE_GROUPS = [
  {
    title: "Lineage",
    names: ["object_references", "table_usage", "process_lineage"],
  },
];

const NAV_AREAS = [
  {
    id: "documentation",
    title: "Documentation",
    pill: "Documentation module",
    heading: "Documentation",
    emptyTitle: "Choose a section",
    emptyDescription: "Select a documentation group from the left menu to review the discovered characteristics.",
    groups: DOCUMENTATION_GROUPS,
  },
  {
    id: "processes",
    title: "Processes",
    pill: "Processes module",
    heading: "Processes",
    emptyTitle: "Processes are next",
    emptyDescription: "This area will evolve into process maps, ownership, lineage, and impact analysis after the job documentation is stable.",
    groups: PROCESS_GROUPS,
  },
  {
    id: "lineage",
    title: "Lineage",
    pill: "Lineage module",
    heading: "Lineage",
    emptyTitle: "Choose a lineage section",
    emptyDescription: "Review object dependencies, table usage, and initial process lineage before moving to graph views.",
    groups: LINEAGE_GROUPS,
  },
  {
    id: "health",
    title: "Health",
    pill: "Health module",
    heading: "Health",
    emptyTitle: "Health checks",
    emptyDescription: "This area will collect alerts and operational checks across documentation and process modules.",
    groups: [],
  },
];

const CARD_GROUPS = {
  server_overview: [
    {
      title: "Identity",
      fields: ["server_name", "machine_name", "instance_name", "host_platform"],
    },
    {
      title: "Version",
      fields: ["edition", "product_version", "product_level", "engine_edition", "server_collation"],
    },
    {
      title: "Inventory",
      fields: ["database_count", "server_login_count", "linked_server_count", "sql_agent_job_count"],
    },
    {
      title: "Runtime",
      fields: ["server_time", "cpu_count"],
    },
    {
      title: "Memory",
      fields: ["physical_memory_gb", "max_server_memory_gb"],
    },
  ],
  database_overview: [
    {
      title: "Identity",
      fields: ["database_name", "server_name", "owner_name", "create_date"],
    },
    {
      title: "Core settings",
      fields: ["compatibility_level", "collation_name", "recovery_model_desc", "state_desc", "page_verify_option_desc"],
    },
    {
      title: "Storage",
      fields: ["allocated_gb", "used_gb", "file_count", "filegroup_count"],
    },
    {
      title: "Structure",
      fields: [
        "schema_count",
        "table_count",
        "view_count",
        "stored_procedure_count",
        "function_count",
        "trigger_count",
        "foreign_key_count",
        "index_count",
      ],
    },
    {
      title: "Security",
      fields: ["database_user_count", "custom_role_count", "server_login_count"],
    },
  ],
  database_properties: [
    {
      title: "Identity",
      fields: ["database_name", "compatibility_level", "collation_name", "recovery_model_desc"],
    },
    {
      title: "Isolation",
      fields: ["snapshot_isolation_state_desc", "is_read_committed_snapshot_on"],
    },
    {
      title: "Statistics",
      fields: ["is_auto_create_stats_on", "is_auto_update_stats_on", "is_auto_update_stats_async_on"],
    },
    {
      title: "Safety",
      fields: ["page_verify_option_desc", "is_auto_close_on", "is_auto_shrink_on", "target_recovery_time_in_seconds"],
    },
    {
      title: "Features",
      fields: ["is_query_store_on", "is_broker_enabled", "is_cdc_enabled", "is_encrypted", "log_reuse_wait_desc"],
    },
  ],
};

const CONNECTION_DRAFT_KEY = "sqlsidekick.connectionDraft";
const SCRIPT_VERSION_KEY = "sqlsidekick.scriptVersion";
const AUTO_ALERTS_KEY = "sqlsidekick.autoAlerts";
const AGENT_CONNECTION_KEY = "sqlsidekick.agentConnection";
const TABLE_PAGE_SIZE = 50;

const GROUP_CATEGORY_SLUGS = {
  Server: "server",
  Database: "database",
  Storage: "storage",
  Structure: "structure",
  Constraints: "constraints",
  "SQL Code": "code",
  "DB Users / Roles": "security",
  "SQL Agent Jobs": "jobs",
  "Process Documentation": "processes",
  Jobs: "processes",
  Analysis: "analysis",
  Operations: "operations",
  Additional: "additional",
  Documentation: "documentation",
  Processes: "processes",
  Lineage: "lineage",
  Health: "health",
};

const state = {
  connection: null,
  connected: false,
  queries: [],
  activeQuery: null,
  activeArea: "documentation",
  activeGroup: "Documentation",
  rows: [],
  columns: [],
  tablePage: 1,
  filterColumn: "",
  failedQueries: new Map(),
  scriptVersion: loadScriptVersion(),
  autoAlerts: loadAutoAlerts(),
  agentConnection: loadAgentConnection(),
  alertsSweepId: 0,
  alertsByCategory: {},
  alerts: {
    groupTitle: "",
    category: "",
    rows: [],
    columns: [],
    error: "",
  },
};

const els = {
  connectionPage: document.querySelector("#connectionPage"),
  appPage: document.querySelector("#appPage"),
  appLayout: document.querySelector("#appLayout"),
  form: document.querySelector("#connectionForm"),
  authType: document.querySelector("#authType"),
  status: document.querySelector("#connectionStatus"),
  appStatus: document.querySelector("#appConnectionStatus"),
  serverLabel: document.querySelector("#serverLabel"),
  databaseLabel: document.querySelector("#databaseLabel"),
  userLabel: document.querySelector("#userLabel"),
  connectButton: document.querySelector("#connectButton"),
  connectionMessage: document.querySelector("#connectionMessage"),
  changeConnection: document.querySelector("#changeConnection"),
  toggleSidebar: document.querySelector("#toggleSidebar"),
  modulePill: document.querySelector("#modulePill"),
  moduleTabs: document.querySelector("#moduleTabs"),
  sidebarTitle: document.querySelector("#sidebarTitle"),
  queryList: document.querySelector("#queryList"),
  refreshQueries: document.querySelector("#refreshQueries"),
  runQuery: document.querySelector("#runQuery"),
  openAlerts: document.querySelector("#openAlerts"),
  alertBadge: document.querySelector("#alertBadge"),
  exportCsv: document.querySelector("#exportCsv"),
  openSettings: document.querySelector("#openSettings"),
  activeGroup: document.querySelector("#activeGroup"),
  title: document.querySelector("#activeTitle"),
  description: document.querySelector("#activeDescription"),
  message: document.querySelector("#message"),
  tableTools: document.querySelector("#tableTools"),
  rowCount: document.querySelector("#rowCount"),
  columnCount: document.querySelector("#columnCount"),
  filterLabel: document.querySelector("#filterLabel"),
  filterText: document.querySelector("#filterText"),
  cardView: document.querySelector("#cardView"),
  table: document.querySelector("#resultTable"),
  tableWrap: document.querySelector(".table-wrap"),
  pagination: document.querySelector("#pagination"),
  paginationInfo: document.querySelector("#paginationInfo"),
  prevPage: document.querySelector("#prevPage"),
  nextPage: document.querySelector("#nextPage"),
  tableDetailDialog: document.querySelector("#tableDetailDialog"),
  tableDetailTitle: document.querySelector("#tableDetailTitle"),
  tableDetailBody: document.querySelector("#tableDetailBody"),
  closeTableDetail: document.querySelector("#closeTableDetail"),
  detailTabs: document.querySelectorAll(".detail-tab"),
  codeDetailDialog: document.querySelector("#codeDetailDialog"),
  codeDetailTitle: document.querySelector("#codeDetailTitle"),
  codeDetailBody: document.querySelector("#codeDetailBody"),
  closeCodeDetail: document.querySelector("#closeCodeDetail"),
  processDetailDialog: document.querySelector("#processDetailDialog"),
  processDetailTitle: document.querySelector("#processDetailTitle"),
  processDetailBody: document.querySelector("#processDetailBody"),
  closeProcessDetail: document.querySelector("#closeProcessDetail"),
  processDetailTabs: document.querySelectorAll(".process-detail-tab"),
  stepObjectsDialog: document.querySelector("#stepObjectsDialog"),
  stepObjectsTitle: document.querySelector("#stepObjectsTitle"),
  stepObjectsBody: document.querySelector("#stepObjectsBody"),
  closeStepObjects: document.querySelector("#closeStepObjects"),
  alertsDialog: document.querySelector("#alertsDialog"),
  alertsTitle: document.querySelector("#alertsTitle"),
  alertsBody: document.querySelector("#alertsBody"),
  closeAlerts: document.querySelector("#closeAlerts"),
  settingsDialog: document.querySelector("#settingsDialog"),
  closeSettings: document.querySelector("#closeSettings"),
  scriptVersionInputs: document.querySelectorAll('input[name="scriptVersion"]'),
  autoAlertsInput: document.querySelector("#autoAlerts"),
  agentCredentialsEnabled: document.querySelector("#agentCredentialsEnabled"),
  agentDatabase: document.querySelector("#agentDatabase"),
  agentUsername: document.querySelector("#agentUsername"),
  agentPassword: document.querySelector("#agentPassword"),
};

function getConnectionPayload() {
  const form = new FormData(els.form);
  return {
    server: String(form.get("server") || ""),
    database: String(form.get("database") || ""),
    authType: String(form.get("authType") || "sql"),
    username: String(form.get("username") || ""),
    password: String(form.get("password") || ""),
    encrypt: document.querySelector("#encrypt").checked,
    trustServerCertificate: document.querySelector("#trustServerCertificate").checked,
  };
}

function fillConnectionForm(connection) {
  if (!connection) return;
  document.querySelector("#server").value = connection.server || "";
  document.querySelector("#database").value = connection.database || "";
  document.querySelector("#authType").value = connection.authType || "sql";
  document.querySelector("#username").value = connection.username || "";
  document.querySelector("#password").value = connection.password || "";
  document.querySelector("#encrypt").checked = Boolean(connection.encrypt);
  document.querySelector("#trustServerCertificate").checked = connection.trustServerCertificate !== false;
  updateAuthFields();
}

function loadConnectionDraft() {
  try {
    const raw = localStorage.getItem(CONNECTION_DRAFT_KEY);
    if (!raw) return;
    fillConnectionForm(JSON.parse(raw));
  } catch {
    localStorage.removeItem(CONNECTION_DRAFT_KEY);
  }
}

function saveConnectionDraft(connection) {
  localStorage.setItem(CONNECTION_DRAFT_KEY, JSON.stringify(connection));
}

function loadScriptVersion() {
  const version = localStorage.getItem(SCRIPT_VERSION_KEY) || "full";
  return ["light", "full"].includes(version) ? version : "full";
}

function loadAutoAlerts() {
  return localStorage.getItem(AUTO_ALERTS_KEY) === "true";
}

function loadAgentConnection() {
  try {
    const raw = localStorage.getItem(AGENT_CONNECTION_KEY);
    if (!raw) {
      return { enabled: false, database: "msdb", username: "", password: "" };
    }
    return { enabled: false, database: "msdb", username: "", password: "", ...JSON.parse(raw) };
  } catch {
    localStorage.removeItem(AGENT_CONNECTION_KEY);
    return { enabled: false, database: "msdb", username: "", password: "" };
  }
}

function saveAgentConnection() {
  state.agentConnection = {
    enabled: Boolean(els.agentCredentialsEnabled?.checked),
    database: String(els.agentDatabase?.value || "msdb").trim() || "msdb",
    username: String(els.agentUsername?.value || "").trim(),
    password: String(els.agentPassword?.value || ""),
  };
  localStorage.setItem(AGENT_CONNECTION_KEY, JSON.stringify(state.agentConnection));
  updateAgentConnectionInputs();
}

function saveAutoAlerts(enabled) {
  state.autoAlerts = Boolean(enabled);
  localStorage.setItem(AUTO_ALERTS_KEY, state.autoAlerts ? "true" : "false");
  updateAutoAlertsInput();
  if (!state.autoAlerts) {
    clearAlerts();
  }
}

function saveScriptVersion(version) {
  state.scriptVersion = ["light", "full"].includes(version) ? version : "full";
  localStorage.setItem(SCRIPT_VERSION_KEY, state.scriptVersion);
  updateScriptVersionInputs();
}

function updateScriptVersionInputs() {
  els.scriptVersionInputs.forEach((input) => {
    input.checked = input.value === state.scriptVersion;
  });
}

function updateAutoAlertsInput() {
  if (els.autoAlertsInput) {
    els.autoAlertsInput.checked = state.autoAlerts;
  }
}

function updateAgentConnectionInputs() {
  if (!els.agentCredentialsEnabled) return;
  const agent = state.agentConnection || {};
  els.agentCredentialsEnabled.checked = Boolean(agent.enabled);
  els.agentDatabase.value = agent.database || "msdb";
  els.agentUsername.value = agent.username || "";
  els.agentPassword.value = agent.password || "";
  const enabled = Boolean(agent.enabled);
  els.agentDatabase.disabled = !enabled;
  els.agentUsername.disabled = !enabled;
  els.agentPassword.disabled = !enabled;
}

function getQueryConnection(useAgent = false) {
  if (!shouldUseAgentConnection()) {
    return state.connection;
  }
  if (!useAgent) {
    return state.connection;
  }
  return {
    ...state.connection,
    database: state.agentConnection.database || "msdb",
    authType: "sql",
    username: state.agentConnection.username || "",
    password: state.agentConnection.password || "",
  };
}

function shouldUseAgentConnection() {
  return (
    state.agentConnection?.enabled &&
    state.agentConnection?.username &&
    state.agentConnection?.password
  );
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const payload = await response.json();
  if (!response.ok || payload.ok === false) {
    throw new Error(payload.error || "Request failed.");
  }
  return payload;
}

function showMessage(target, text, type = "") {
  target.textContent = text;
  target.className = `message ${type}`.trim();
}

function clearMessage(target) {
  target.textContent = "";
  target.className = "message hidden";
}

function updateAuthFields() {
  const showSqlAuth = els.authType.value === "sql";
  document.querySelectorAll(".sql-auth").forEach((item) => {
    item.classList.toggle("hidden", !showSqlAuth);
  });
}

function goToApp() {
  els.connectionPage.classList.add("hidden");
  els.appPage.classList.remove("hidden");
  els.serverLabel.textContent = state.connection.server;
  els.databaseLabel.textContent = state.connection.database;
  els.userLabel.textContent = state.connection.authType === "windows" ? "Windows Integrated" : state.connection.username;
  els.appStatus.textContent = "Connected";
  els.appStatus.classList.add("ok");
}

function goToConnection() {
  els.appPage.classList.add("hidden");
  els.connectionPage.classList.remove("hidden");
}

async function loadQueries() {
  renderQueryMenuLoading();
  state.failedQueries.clear();
  const payload = await api(`/api/queries?version=${encodeURIComponent(state.scriptVersion)}`);
  state.queries = payload.queries;
  state.activeQuery = null;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  clearAlerts();
  renderModuleTabs();
  renderQueryMenu();
  resetWorkspace();
}

async function loadDefaultConnection() {
  try {
    const payload = await api("/api/default-connection");
    if (payload.connection) {
      fillConnectionForm(payload.connection);
    }
  } catch {
    return;
  }
}

function renderQueryMenu() {
  els.queryList.innerHTML = "";
  const area = getActiveArea();
  const groups = getVisibleGroups(area);
  const usedNames = new Set(getAllQueryGroups().flatMap((group) => group.names));
  updateAreaChrome(area);

  groups.forEach((group, index) => {
    const details = document.createElement("details");
    details.className = "menu-group";
    details.dataset.category = groupCategorySlug(group.title);
    details.open = group.collapsed ? false : index < 2;

    const summary = document.createElement("summary");
    const title = document.createElement("span");
    title.className = "menu-group-title";
    title.textContent = group.title;
    const alertIcon = document.createElement("span");
    alertIcon.className = "menu-alert-icon hidden";
    alertIcon.textContent = "!";
    summary.append(title, alertIcon);
    details.appendChild(summary);

    const items = document.createElement("div");
    items.className = "menu-items";

    group.names
      .map((name) => state.queries.find((query) => query.name === name))
      .filter(Boolean)
      .forEach((query) => {
        usedNames.add(query.name);
        items.appendChild(createQueryButton(query, group.title));
      });

    if (items.children.length > 0) {
      details.appendChild(items);
      els.queryList.appendChild(details);
    }
  });

  if (els.queryList.children.length === 0) {
    const empty = document.createElement("div");
    empty.className = "module-empty";
    empty.innerHTML = `
      <strong>${escapeHtml(area.emptyTitle)}</strong>
      <span>${escapeHtml(area.emptyDescription)}</span>
    `;
    els.queryList.appendChild(empty);
  }
  renderGroupAlertBadges();
}

function renderModuleTabs() {
  if (!els.moduleTabs) return;
  els.moduleTabs.innerHTML = "";
  NAV_AREAS.forEach((area) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "module-tab";
    button.dataset.area = area.id;
    button.textContent = area.title;
    button.classList.toggle("active", area.id === state.activeArea);
    button.addEventListener("click", () => switchArea(area.id));
    els.moduleTabs.appendChild(button);
  });
}

function switchArea(areaId) {
  if (state.activeArea === areaId) return;
  state.activeArea = areaId;
  state.activeQuery = null;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  renderModuleTabs();
  renderQueryMenu();
  resetWorkspace();
}

function getActiveArea() {
  return NAV_AREAS.find((area) => area.id === state.activeArea) || NAV_AREAS[0];
}

function getAllQueryGroups() {
  return NAV_AREAS.flatMap((area) => area.groups);
}

function getVisibleGroups(area = getActiveArea()) {
  return area.groups.filter((group) => group.names.some((name) => state.queries.some((query) => query.name === name)));
}

function updateAreaChrome(area = getActiveArea()) {
  if (els.modulePill) els.modulePill.textContent = area.pill;
  if (els.sidebarTitle) els.sidebarTitle.textContent = area.heading;
}

function renderQueryMenuLoading() {
  if (!els.queryList) return;
  els.queryList.innerHTML = `
    <div class="menu-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Refreshing menu</span>
    </div>
  `;
}

function createQueryButton(query, groupTitle) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "query-item";
  button.dataset.name = query.name;
  button.dataset.group = groupTitle;
  const failedReason = state.failedQueries.get(query.name);
  if (failedReason) {
    button.classList.add("failed");
    button.disabled = true;
    button.title = failedReason;
  } else {
    button.title = query.description;
  }
  button.innerHTML = `
    <span class="query-state-icon" aria-hidden="true">${failedReason ? "!" : ""}</span>
    <span class="query-copy">
      <strong>${escapeHtml(query.title)}</strong>
    </span>
  `;
  button.addEventListener("click", () => selectAndRunQuery(query.name, groupTitle));
  return button;
}

async function selectAndRunQuery(name, groupTitle) {
  setActiveQuery(name, groupTitle);
  if (state.connected) {
    setCurrentAlertsFromGroup(groupTitle);
    if (state.autoAlerts && !getStoredAlerts(groupTitle)) {
      runAlertCheck(groupTitle);
    }
    await runActiveQuery();
  } else {
    showMessage(els.message, "Connect first, then select a section to load its data.", "error");
  }
}

function setActiveQuery(name, groupTitle) {
  state.activeQuery = state.queries.find((query) => query.name === name);
  state.activeGroup = groupTitle;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  els.filterText.value = "";
  document.querySelectorAll(".query-item").forEach((item) => {
    item.classList.toggle("active", item.dataset.name === name);
  });
  els.activeGroup.textContent = groupTitle;
  els.title.textContent = state.activeQuery.title;
  els.description.textContent = state.activeQuery.description;
  els.runQuery.disabled = !state.connected;
  els.rowCount.textContent = "0";
  els.columnCount.textContent = "0";
  els.exportCsv.disabled = true;
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  els.tableTools.classList.add("hidden");
  els.pagination.classList.add("hidden");
  renderLoadingState();
  clearMessage(els.message);
}

async function runAllAlerts() {
  if (!state.autoAlerts || !state.connected || !state.connection) {
    return;
  }
  const sweepId = state.alertsSweepId + 1;
  state.alertsSweepId = sweepId;
  state.alertsByCategory = {};
  setCurrentAlertsFromGroup(state.activeGroup);
  renderGroupAlertBadges();

  await Promise.all(getAlertableGroups().map((group) => runAlertCheck(group.title, sweepId)));
}

async function runAlertCheck(groupTitle, sweepId = state.alertsSweepId) {
  if (!state.autoAlerts || !state.connected || !state.connection) {
    return;
  }
  const category = groupCategorySlug(groupTitle);
  if (!category || category === "additional" || category === "documentation") {
    return;
  }

  try {
    const payload = await api("/api/run-alerts", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        category,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    if (sweepId !== state.alertsSweepId) return;
    state.alertsByCategory[category] = {
      groupTitle,
      category,
      rows: resultSet.rows || [],
      columns: resultSet.columns || [],
      error: "",
    };
  } catch (error) {
    if (sweepId !== state.alertsSweepId) return;
    state.alertsByCategory[category] = {
      groupTitle,
      category,
      rows: [],
      columns: [],
      error: error.message,
    };
  }
  renderGroupAlertBadges();
  if (state.activeGroup === groupTitle) {
    setCurrentAlertsFromGroup(groupTitle);
  }
}

function groupCategorySlug(groupTitle) {
  return GROUP_CATEGORY_SLUGS[groupTitle] || String(groupTitle || "").toLowerCase().replaceAll(" ", "_");
}

function getAlertableGroups() {
  return getAllQueryGroups().filter((group) => {
    const category = groupCategorySlug(group.title);
    if (!category || category === "additional" || category === "documentation") return false;
    return group.names.some((name) => state.queries.some((query) => query.name === name));
  });
}

function getStoredAlerts(groupTitle) {
  return state.alertsByCategory[groupCategorySlug(groupTitle)];
}

function setCurrentAlertsFromGroup(groupTitle) {
  const category = groupCategorySlug(groupTitle);
  state.alerts = state.alertsByCategory[category] || {
    groupTitle,
    category,
    rows: [],
    columns: [],
    error: "",
  };
  renderAlertIndicator();
}

function renderGroupAlertBadges() {
  document.querySelectorAll(".menu-group").forEach((group) => {
    const category = group.dataset.category;
    const alertState = state.alertsByCategory[category];
    const icon = group.querySelector(".menu-alert-icon");
    if (!icon) return;
    const hasAlerts = Boolean(alertState?.rows?.length);
    const hasError = Boolean(alertState?.error);
    const severity = getHighestAlertSeverity(alertState);
    icon.classList.toggle("hidden", !hasAlerts && !hasError);
    icon.classList.toggle("failed", hasError);
    setSeverityClasses(icon, severity);
    icon.title = hasError ? "Alert check failed" : "Alerts detected";
  });
}

function clearAlerts() {
  state.alertsSweepId += 1;
  state.alertsByCategory = {};
  state.alerts = { groupTitle: "", category: "", rows: [], columns: [], error: "" };
  els.openAlerts.classList.add("hidden");
  els.openAlerts.classList.remove("has-alerts", "failed");
  els.alertBadge.textContent = "0";
  renderGroupAlertBadges();
}

function renderAlertIndicator() {
  const hasRows = state.alerts.rows.length > 0;
  const hasError = Boolean(state.alerts.error);
  const severity = getHighestAlertSeverity(state.alerts);
  els.openAlerts.classList.toggle("hidden", !hasRows && !hasError);
  els.openAlerts.classList.toggle("has-alerts", hasRows);
  els.openAlerts.classList.toggle("failed", hasError);
  setSeverityClasses(els.openAlerts, severity);
  els.openAlerts.title = hasError ? "Alert check failed" : `Open ${state.alerts.rows.length} alerts`;
  els.openAlerts.setAttribute("aria-label", els.openAlerts.title);
  els.alertBadge.textContent = hasError ? "!" : String(state.alerts.rows.length);
}

function getHighestAlertSeverity(alertState) {
  const firstRow = alertState?.rows?.[0];
  const explicitSeverity = normalizeAlertSeverity(firstRow?.highest_detected_severity);
  if (explicitSeverity !== "unknown") {
    return explicitSeverity;
  }
  const ranks = { high: 1, medium: 2, low: 3, unknown: 4 };
  return (alertState?.rows || []).reduce((highest, row) => {
    const severity = normalizeAlertSeverity(row.severity);
    return ranks[severity] < ranks[highest] ? severity : highest;
  }, "unknown");
}

function normalizeAlertSeverity(value) {
  const severity = String(value || "").trim().toLowerCase();
  return ["high", "medium", "low"].includes(severity) ? severity : "unknown";
}

function setSeverityClasses(element, severity) {
  element.classList.remove("severity-high", "severity-medium", "severity-low", "severity-unknown");
  element.classList.add(`severity-${severity || "unknown"}`);
}

function openAlertsPanel() {
  els.alertsTitle.textContent = state.alerts.groupTitle ? `${state.alerts.groupTitle} alerts` : "Alerts";
  if (state.alerts.error) {
    els.alertsBody.innerHTML = `<div class="alert-error">${escapeHtml(state.alerts.error)}</div>`;
    els.alertsDialog.showModal();
    return;
  }
  if (state.alerts.rows.length === 0) {
    els.alertsBody.innerHTML = `<div class="empty">No active alerts.</div>`;
    els.alertsDialog.showModal();
    return;
  }
  els.alertsBody.innerHTML = renderAlertsTable();
  els.alertsDialog.showModal();
}

function renderAlertsTable() {
  const visibleColumns = state.alerts.columns.filter((column) => column !== "highest_detected_severity");
  const headers = visibleColumns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`).join("");
  const rows = state.alerts.rows
    .map((row) => {
      const severity = String(row.severity || "").toLowerCase();
      const cells = visibleColumns
        .map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`)
        .join("");
      return `<tr class="alert-row alert-${escapeHtml(severity)}">${cells}</tr>`;
    })
    .join("");
  return `
    <div class="alerts-summary">
      <strong>${state.alerts.rows.length}</strong>
      <span>active alerts detected for this category.</span>
    </div>
    <div class="alerts-table-wrap">
      <table class="alerts-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

async function testConnection(event) {
  event.preventDefault();
  clearMessage(els.connectionMessage);
  state.connection = getConnectionPayload();
  saveConnectionDraft(state.connection);
  els.status.textContent = "Testing...";
  els.status.classList.remove("ok");
  els.connectButton.disabled = true;
  els.connectButton.textContent = "Testing...";
  try {
    await api("/api/test-connection", {
      method: "POST",
      body: JSON.stringify({ connection: state.connection }),
    });
    state.connected = true;
    els.status.textContent = "Connected";
    els.status.classList.add("ok");
    els.runQuery.disabled = !state.activeQuery;
    showMessage(els.connectionMessage, "Connection successful. Opening the explorer.", "success");
    goToApp();
    if (!state.activeQuery && state.queries.length > 0) {
      const firstDatabaseQuery = state.queries.find((query) => query.name === "database_overview") || state.queries[0];
      setActiveQuery(firstDatabaseQuery.name, "Database");
      runAllAlerts();
      await runActiveQuery();
    }
  } catch (error) {
    state.connected = false;
    els.status.textContent = "Disconnected";
    els.status.classList.remove("ok");
    els.runQuery.disabled = true;
    showMessage(els.connectionMessage, error.message, "error");
  } finally {
    els.connectButton.disabled = false;
    els.connectButton.textContent = "Test and enter";
  }
}

async function runActiveQuery() {
  if (!state.activeQuery || !state.connection) return;
  clearMessage(els.message);
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  renderLoadingState();
  els.runQuery.disabled = true;
  els.runQuery.innerHTML = `<span class="icon-loading-dot" aria-hidden="true"></span>`;
  try {
    const payload = await api("/api/run-query", {
      method: "POST",
      body: JSON.stringify({
        connection: getQueryConnection(),
        queryName: state.activeQuery.name,
        scriptVersion: state.scriptVersion,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    state.columns = resultSet.columns || [];
    state.rows = resultSet.rows || [];
    state.tablePage = 1;
    state.filterColumn = getDefaultFilterColumn();
    updateTableFilterUI();
    renderResults();
    clearMessage(els.message);
  } catch (error) {
    markQueryFailed(state.activeQuery.name, error.message);
    showMessage(els.message, error.message, "error");
  } finally {
    els.runQuery.disabled = !state.connected || state.failedQueries.has(state.activeQuery?.name);
    els.runQuery.innerHTML = `<span class="icon-refresh" aria-hidden="true">↻</span>`;
  }
}

function markQueryFailed(queryName, reason) {
  state.failedQueries.set(queryName, reason || "Query failed.");
  const button = Array.from(document.querySelectorAll(".query-item")).find((item) => item.dataset.name === queryName);
  if (!button) return;
  button.classList.add("failed");
  button.disabled = true;
  button.title = state.failedQueries.get(queryName);
  const icon = button.querySelector(".query-state-icon");
  if (icon) icon.textContent = "!";
  if (state.activeQuery?.name === queryName) {
    els.runQuery.disabled = true;
  }
}

function resetWorkspace() {
  const area = getActiveArea();
  updateAreaChrome(area);
  els.activeGroup.textContent = area.title;
  els.title.textContent = area.emptyTitle;
  els.description.textContent = area.emptyDescription;
  els.runQuery.disabled = true;
  els.exportCsv.disabled = true;
  clearAlerts();
  els.tableTools.classList.add("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  els.pagination.classList.add("hidden");
  renderEmptyTable("No results yet.");
  clearMessage(els.message);
}

function renderResults() {
  if (state.rows.length <= 1) {
    renderCards();
    return;
  }
  els.message.classList.remove("hidden");
  els.tableTools.classList.remove("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  renderTable();
}

function renderCards() {
  const row = state.rows[0] || {};
  els.rowCount.textContent = String(state.rows.length);
  els.columnCount.textContent = String(state.columns.length);
  els.exportCsv.disabled = state.rows.length === 0;
  els.message.classList.add("hidden");
  els.tableTools.classList.add("hidden");
  els.tableWrap.classList.add("hidden");
  els.pagination.classList.add("hidden");
  els.cardView.classList.remove("hidden");
  els.cardView.innerHTML = "";

  if (state.columns.length === 0) {
    els.cardView.innerHTML = `<div class="empty card-empty">No values to display.</div>`;
    return;
  }

  const groups = getCardGroups();
  groups.forEach((group) => {
    const section = document.createElement("section");
    section.className = "multirow-card";
    const title = document.createElement("h3");
    title.textContent = group.title;
    const metrics = document.createElement("div");
    metrics.className = "multirow-metrics";

    group.fields.forEach((field) => {
      if (!state.columns.includes(field)) return;
      const metric = document.createElement("div");
      metric.className = "multirow-metric";
      const value = document.createElement("strong");
      value.textContent = formatValue(row[field]);
      value.title = value.textContent;
      value.className = value.textContent.length > 20 ? "compact-value" : "";
      const label = document.createElement("span");
      label.textContent = labelize(field);
      metric.append(value, label);
      metrics.appendChild(metric);
    });

    if (metrics.children.length > 0) {
      section.append(title, metrics);
      els.cardView.appendChild(section);
    }
  });
}

function getCardGroups() {
  const configured = CARD_GROUPS[state.activeQuery?.name] || [];
  if (configured.length > 0) return configured;
  return [{ title: "Details", fields: state.columns }];
}

function renderTable() {
  const filter = els.filterText.value.trim().toLowerCase();
  const rows = filter
    ? state.rows.filter((row) => rowMatchesFilter(row, filter))
    : state.rows;
  const totalPages = Math.max(1, Math.ceil(rows.length / TABLE_PAGE_SIZE));
  state.tablePage = Math.min(Math.max(1, state.tablePage), totalPages);
  const startIndex = (state.tablePage - 1) * TABLE_PAGE_SIZE;
  const visibleRows = rows.slice(startIndex, startIndex + TABLE_PAGE_SIZE);

  els.rowCount.textContent = String(rows.length);
  els.columnCount.textContent = String(state.columns.length);
  els.exportCsv.disabled = rows.length === 0;
  els.tableTools.classList.remove("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  updatePagination(rows.length, totalPages, startIndex, visibleRows.length);

  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = "";

  if (state.columns.length === 0) {
    renderEmptyTable("No columns to display.");
    return;
  }

  const headRow = document.createElement("tr");
  if (hasRowDetail()) {
    const detailTh = document.createElement("th");
    detailTh.textContent = "";
    detailTh.className = "row-action-header";
    headRow.appendChild(detailTh);
  }
  state.columns.forEach((column) => {
    const th = document.createElement("th");
    th.textContent = labelize(column);
    th.title = column;
    headRow.appendChild(th);
  });
  thead.appendChild(headRow);

  if (rows.length === 0) {
    const td = document.createElement("td");
    td.className = "empty";
    td.colSpan = state.columns.length + (hasRowDetail() ? 1 : 0);
    td.textContent = "No rows to display.";
    const tr = document.createElement("tr");
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  visibleRows.forEach((row) => {
    const tr = document.createElement("tr");
    if (hasRowDetail()) {
      const actionTd = document.createElement("td");
      actionTd.className = "row-action-cell";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "row-detail-button";
      button.title = getRowDetailTitle();
      button.setAttribute("aria-label", button.title);
      button.textContent = "i";
      button.addEventListener("click", () => {
        if (isTablesQuery()) {
          openTableDetail(row);
        } else if (isCodeQuery()) {
          openCodeDetail(row);
        } else if (isProcessInventoryQuery()) {
          openProcessDetail(row);
        }
      });
      actionTd.appendChild(button);
      tr.appendChild(actionTd);
    }
    state.columns.forEach((column) => {
      const td = document.createElement("td");
      td.textContent = row[column] ?? "";
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

function rowMatchesFilter(row, filter) {
  if (state.filterColumn && state.columns.includes(state.filterColumn)) {
    return String(row[state.filterColumn] ?? "").toLowerCase().includes(filter);
  }
  return state.columns.some((column) => String(row[column] ?? "").toLowerCase().includes(filter));
}

function getDefaultFilterColumn() {
  const preferredByQuery = {
    tables: ["table_name"],
    procedures: ["procedure_name", "object_name"],
    views: ["view_name", "object_name"],
    functions: ["function_name", "object_name"],
    triggers: ["trigger_name", "object_name"],
    columns: ["column_name", "object_name", "table_name"],
    indexes: ["index_name", "table_name"],
    foreign_keys: ["foreign_key_name", "parent_table", "referenced_table"],
    schemas: ["schema_name"],
    database_files: ["logical_name", "physical_name"],
    filegroups: ["filegroup_name"],
    server_databases_summary: ["database_name"],
    database_scoped_configurations: ["configuration_name"],
    database_extended_properties: ["property_name"],
    database_principals: ["principal_name", "user_name", "name"],
    database_roles: ["role_name", "name"],
    database_role_members: ["role_name", "member_name"],
    database_permissions: ["grantee_name", "principal_name", "permission_name"],
    server_logins: ["login_name", "name"],
    server_role_members: ["member_name", "role_name"],
    linked_servers: ["linked_server_name", "name"],
    server_configurations: ["configuration_name", "name"],
    server_services: ["service_name", "servicename"],
    sql_agent_jobs: ["job_name"],
    sql_agent_job_steps: ["job_name", "step_name"],
    sql_agent_job_schedules: ["job_name", "schedule_name"],
    sql_agent_job_history: ["job_name"],
    process_inventory: ["process_name"],
    process_steps: ["process_name", "step_name"],
    process_sql_objects: ["process_name", "object_name", "schema_name"],
    process_recent_runs: ["process_name", "run_status"],
    object_references: ["source_object", "target_object", "source_schema", "target_schema"],
    table_usage: ["table_name", "used_by_object", "table_schema"],
    process_lineage: ["process_name", "called_object_name", "referenced_object"],
  };
  const candidates = preferredByQuery[state.activeQuery?.name] || [];
  return candidates.find((column) => state.columns.includes(column)) || inferNameColumn();
}

function inferNameColumn() {
  return (
    state.columns.find((column) => column.endsWith("_name")) ||
    state.columns.find((column) => column === "name") ||
    ""
  );
}

function updateTableFilterUI() {
  const label = state.filterColumn ? `Filter by ${labelize(state.filterColumn)}` : "Filter";
  els.filterLabel.textContent = label;
  els.filterText.placeholder = state.filterColumn ? `filter ${labelize(state.filterColumn).toLowerCase()}...` : "filter results...";
}

function isTablesQuery() {
  return state.activeQuery?.name === "tables";
}

function isCodeQuery() {
  return ["views", "procedures", "functions", "triggers"].includes(state.activeQuery?.name);
}

function isProcessInventoryQuery() {
  return state.activeQuery?.name === "process_inventory";
}

function hasRowDetail() {
  return isTablesQuery() || isCodeQuery() || isProcessInventoryQuery();
}

function getRowDetailTitle() {
  if (isTablesQuery()) return "Open table detail";
  if (isCodeQuery()) return "Open SQL code detail";
  if (isProcessInventoryQuery()) return "Open process detail";
  return "Open detail";
}

async function openTableDetail(row) {
  const schemaName = row.schema_name;
  const tableName = row.table_name;
  if (!schemaName || !tableName || !state.connection) return;

  els.tableDetailTitle.textContent = `${schemaName}.${tableName}`;
  setActiveDetailTab("columns");
  els.tableDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading table detail</span>
    </div>
  `;
  els.tableDetailDialog.showModal();

  try {
    const payload = await api("/api/table-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        schemaName,
        tableName,
      }),
    });
    const detail = {
      columns: payload.resultSets?.[0] || { columns: [], rows: [] },
      indexes: payload.resultSets?.[1] || { columns: [], rows: [] },
      foreignKeys: payload.resultSets?.[2] || { columns: [], rows: [] },
      sqlCode: payload.resultSets?.[3] || { columns: [], rows: [] },
    };
    els.tableDetailDialog.dataset.detail = JSON.stringify(detail);
    renderTableDetailTab("columns");
  } catch (error) {
    els.tableDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openCodeDetail(row) {
  const schemaName = row.schema_name;
  const objectName = getCodeObjectName(row);
  if (!schemaName || !objectName || !state.connection) return;

  els.codeDetailTitle.textContent = `${schemaName}.${objectName}`;
  els.codeDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading referenced objects</span>
    </div>
  `;
  els.codeDetailDialog.showModal();

  try {
    const payload = await api("/api/code-object-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        schemaName,
        objectName,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    els.codeDetailBody.innerHTML = renderDetailResultSet(resultSet);
  } catch (error) {
    els.codeDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openProcessDetail(row) {
  const processName = row.process_name;
  if (!processName || !state.connection) return;

  els.processDetailTitle.textContent = processName;
  setActiveProcessDetailTab("overview");
  els.processDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading process detail</span>
    </div>
  `;
  els.processDetailDialog.showModal();

  try {
    const primaryPayload = await api("/api/process-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: getQueryConnection(),
        processName,
        jobId: row.job_id || "",
      }),
    });
    let stepsResultSet = primaryPayload.resultSets?.[1] || { columns: [], rows: [] };

    if (shouldUseAgentConnection()) {
      try {
        const agentPayload = await api("/api/process-detail", {
          method: "POST",
          body: JSON.stringify({
            connection: getQueryConnection(true),
            processName,
            jobId: row.job_id || "",
          }),
        });
        stepsResultSet = agentPayload.resultSets?.[1] || stepsResultSet;
      } catch {
        stepsResultSet = primaryPayload.resultSets?.[1] || { columns: [], rows: [] };
      }
    }

    const detail = {
      overview: primaryPayload.resultSets?.[0] || { columns: [], rows: [] },
      steps: stepsResultSet,
      recentRuns: primaryPayload.resultSets?.[2] || { columns: [], rows: [] },
      processName,
      jobId: row.job_id || "",
    };
    els.processDetailDialog.dataset.detail = JSON.stringify(detail);
    renderProcessDetailTab("overview");
  } catch (error) {
    els.processDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openProcessStepSqlObjects(row) {
  const detail = JSON.parse(els.processDetailDialog.dataset.detail || "{}");
  const processName = detail.processName;
  const jobId = detail.jobId || "";
  const stepOrder = Number(row.step_order || row.step_id || 0);
  if (!processName || !stepOrder || !state.connection) return;

  els.stepObjectsTitle.textContent = `${processName} - Step ${stepOrder}`;
  els.stepObjectsBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading SQL objects</span>
    </div>
  `;
  els.stepObjectsDialog.showModal();

  try {
    const payload = await api("/api/process-step-sql-objects", {
      method: "POST",
      body: JSON.stringify({
        connection: getQueryConnection(true),
        processName,
        jobId,
        stepOrder,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    els.stepObjectsBody.innerHTML = renderDetailResultSet(resultSet);
  } catch (error) {
    els.stepObjectsBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

function getCodeObjectName(row) {
  const nameColumns = {
    views: "view_name",
    procedures: "procedure_name",
    functions: "function_name",
    triggers: "trigger_name",
  };
  return row[nameColumns[state.activeQuery?.name]] || row.object_name || "";
}

function setActiveDetailTab(tabName) {
  els.detailTabs.forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.tab === tabName);
  });
}

function renderTableDetailTab(tabName) {
  setActiveDetailTab(tabName);
  const detail = JSON.parse(els.tableDetailDialog.dataset.detail || "{}");
  const resultSet = detail[tabName] || { columns: [], rows: [] };
  els.tableDetailBody.innerHTML = renderDetailResultSet(resultSet);
}

function setActiveProcessDetailTab(tabName) {
  els.processDetailTabs.forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.tab === tabName);
  });
}

function renderProcessDetailTab(tabName) {
  setActiveProcessDetailTab(tabName);
  const detail = JSON.parse(els.processDetailDialog.dataset.detail || "{}");
  const resultSet = detail[tabName] || { columns: [], rows: [] };
  els.processDetailBody.innerHTML = tabName === "steps" ? renderProcessStepsResultSet(resultSet) : renderDetailResultSet(resultSet);
}

function renderProcessStepsResultSet(resultSet) {
  const columns = resultSet.columns || [];
  const rows = resultSet.rows || [];
  if (columns.length === 0) {
    return `<div class="empty">No step columns to display.</div>`;
  }
  if (rows.length === 0) {
    return `<div class="empty">No steps to display.</div>`;
  }
  const headers = [`<th class="row-action-header"></th>`, ...columns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`)].join("");
  const body = rows
    .map((row, index) => {
      const encoded = encodeURIComponent(JSON.stringify(row));
      const cells = columns.map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`).join("");
      return `
        <tr>
          <td class="row-action-cell">
            <button type="button" class="row-detail-button process-step-object-button" data-row="${encoded}" title="Open SQL objects" aria-label="Open SQL objects">i</button>
          </td>
          ${cells}
        </tr>
      `;
    })
    .join("");
  setTimeout(() => {
    document.querySelectorAll(".process-step-object-button").forEach((button) => {
      button.addEventListener("click", () => {
        openProcessStepSqlObjects(JSON.parse(decodeURIComponent(button.dataset.row || "%7B%7D")));
      });
    });
  }, 0);
  return `
    <div class="detail-table-wrap">
      <table class="detail-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
}

function renderDetailResultSet(resultSet) {
  const columns = resultSet.columns || [];
  const rows = resultSet.rows || [];
  if (columns.length === 0) {
    return `<div class="empty">No detail columns to display.</div>`;
  }
  if (rows.length === 0) {
    return `<div class="empty">No rows to display.</div>`;
  }
  const headers = columns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`).join("");
  const body = rows
    .map((row) => {
      const cells = columns.map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`).join("");
      return `<tr>${cells}</tr>`;
    })
    .join("");
  return `
    <div class="detail-table-wrap">
      <table class="detail-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
}

function updatePagination(totalRows, totalPages, startIndex, visibleCount) {
  els.pagination.classList.toggle("hidden", totalRows <= TABLE_PAGE_SIZE);
  if (totalRows <= TABLE_PAGE_SIZE) {
    return;
  }
  const endIndex = startIndex + visibleCount;
  els.paginationInfo.textContent = `Rows ${startIndex + 1}-${endIndex} of ${totalRows} | Page ${state.tablePage} of ${totalPages}`;
  els.prevPage.disabled = state.tablePage <= 1;
  els.nextPage.disabled = state.tablePage >= totalPages;
}

function changePage(delta) {
  state.tablePage += delta;
  renderTable();
}

function renderEmptyTable(message) {
  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = `<tr><td class="empty">${escapeHtml(message)}</td></tr>`;
  els.pagination.classList.add("hidden");
}

function renderLoadingState() {
  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = `
    <tr>
      <td class="empty">
        <div class="loading-state">
          <div class="loading-spinner" aria-hidden="true"></div>
          <div>
            <strong>Loading section data</strong>
            <span>Running the SQL query and preparing the result view.</span>
          </div>
          <div class="loading-bar" aria-hidden="true"><span></span></div>
        </div>
      </td>
    </tr>
  `;
}

function exportCsv() {
  const lines = [
    state.columns.map((column) => csvValue(labelize(column))).join(","),
    ...state.rows.map((row) => state.columns.map((column) => csvValue(row[column])).join(",")),
  ];
  const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${state.activeQuery?.name || "sqlsidekick"}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

function csvValue(value) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function labelize(value) {
  return String(value)
    .replaceAll("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase())
    .replace(/\bDatabase\b/g, "DB")
    .replace(/\bGb\b/g, "GB")
    .replace(/\bMb\b/g, "MB")
    .replace(/\bSql\b/g, "SQL")
    .replace(/\bId\b/g, "ID")
    .replace(/\bCpu\b/g, "CPU")
    .replace(/\bDml\b/g, "DML")
    .replace(/\bDdl\b/g, "DDL")
    .replace(/\bDmv\b/g, "DMV")
    .replace(/\bHadr\b/g, "HADR")
    .replace(/\bAnsi\b/g, "ANSI")
    .replace(/\bIo\b/g, "IO")
    .replace(/\bUrl\b/g, "URL")
    .replace(/\bXml\b/g, "XML")
    .replace(/\bJson\b/g, "JSON")
    .replace(/\bRpc\b/g, "RPC")
    .replace(/\bTcp\b/g, "TCP");
}

function formatValue(value) {
  if (value === null || value === undefined || value === "") return "-";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return String(value);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

els.form.addEventListener("submit", testConnection);
els.authType.addEventListener("change", updateAuthFields);
els.refreshQueries.addEventListener("click", loadQueries);
els.runQuery.addEventListener("click", async () => {
  if (state.autoAlerts) {
    runAlertCheck(state.activeGroup);
  }
  await runActiveQuery();
});
els.exportCsv.addEventListener("click", exportCsv);
els.filterText.addEventListener("input", () => {
  state.tablePage = 1;
  renderTable();
});
els.prevPage.addEventListener("click", () => changePage(-1));
els.nextPage.addEventListener("click", () => changePage(1));
els.openAlerts.addEventListener("click", openAlertsPanel);
els.closeAlerts.addEventListener("click", () => els.alertsDialog.close());
els.closeTableDetail.addEventListener("click", () => els.tableDetailDialog.close());
els.closeCodeDetail.addEventListener("click", () => els.codeDetailDialog.close());
els.closeProcessDetail.addEventListener("click", () => els.processDetailDialog.close());
els.closeStepObjects.addEventListener("click", () => els.stepObjectsDialog.close());
els.detailTabs.forEach((tab) => {
  tab.addEventListener("click", () => renderTableDetailTab(tab.dataset.tab));
});
els.processDetailTabs.forEach((tab) => {
  tab.addEventListener("click", () => renderProcessDetailTab(tab.dataset.tab));
});
els.openSettings.addEventListener("click", () => {
  updateScriptVersionInputs();
  updateAutoAlertsInput();
  updateAgentConnectionInputs();
  els.settingsDialog.showModal();
});
els.closeSettings.addEventListener("click", () => els.settingsDialog.close());
els.autoAlertsInput.addEventListener("change", () => {
  saveAutoAlerts(els.autoAlertsInput.checked);
  if (state.autoAlerts && state.connected && state.activeQuery) {
    runAllAlerts();
  }
});
els.agentCredentialsEnabled.addEventListener("change", saveAgentConnection);
els.agentDatabase.addEventListener("input", saveAgentConnection);
els.agentUsername.addEventListener("input", saveAgentConnection);
els.agentPassword.addEventListener("input", saveAgentConnection);
els.scriptVersionInputs.forEach((input) => {
  input.addEventListener("change", async () => {
    saveScriptVersion(input.value);
    await loadQueries();
    if (state.connected) {
      const firstDatabaseQuery = state.queries.find((query) => query.name === "database_overview") || state.queries[0];
      if (firstDatabaseQuery) {
        state.activeArea = "documentation";
        renderModuleTabs();
        renderQueryMenu();
        setActiveQuery(firstDatabaseQuery.name, firstDatabaseQuery.name === "database_overview" ? "Database" : "Documentation");
        runAllAlerts();
        await runActiveQuery();
      }
    }
    els.settingsDialog.close();
  });
});
els.changeConnection.addEventListener("click", goToConnection);
els.toggleSidebar.addEventListener("click", () => {
  els.appLayout.classList.toggle("sidebar-collapsed");
});

async function initializeApp() {
  updateAuthFields();
  updateScriptVersionInputs();
  updateAutoAlertsInput();
  updateAgentConnectionInputs();
  loadConnectionDraft();
  await loadDefaultConnection();
  await loadQueries();
}

initializeApp().catch((error) => {
  showMessage(els.connectionMessage, error.message, "error");
});
