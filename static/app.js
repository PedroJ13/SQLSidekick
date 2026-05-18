const QUERY_GROUPS = [
  {
    title: "Database",
    names: ["database_overview", "database_properties"],
  },
  { title: "Storage", names: ["database_files", "filegroups", "space_usage"] },
  { title: "Structure", names: ["schemas", "objects", "tables", "columns", "indexes", "foreign_keys"] },
  { title: "SQL Code", names: ["modules"] },
];

const CARD_QUERIES = new Set(["database_overview", "database_properties"]);

const CARD_GROUPS = {
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
        "sql_agent_job_count",
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

const state = {
  connection: null,
  connected: false,
  queries: [],
  activeQuery: null,
  activeGroup: "Documentation",
  rows: [],
  columns: [],
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
  queryList: document.querySelector("#queryList"),
  refreshQueries: document.querySelector("#refreshQueries"),
  runQuery: document.querySelector("#runQuery"),
  viewSql: document.querySelector("#viewSql"),
  exportCsv: document.querySelector("#exportCsv"),
  activeGroup: document.querySelector("#activeGroup"),
  title: document.querySelector("#activeTitle"),
  description: document.querySelector("#activeDescription"),
  message: document.querySelector("#message"),
  summary: document.querySelector("#summary"),
  rowCount: document.querySelector("#rowCount"),
  columnCount: document.querySelector("#columnCount"),
  filterText: document.querySelector("#filterText"),
  cardView: document.querySelector("#cardView"),
  table: document.querySelector("#resultTable"),
  tableWrap: document.querySelector(".table-wrap"),
  sqlDialog: document.querySelector("#sqlDialog"),
  sqlPreview: document.querySelector("#sqlPreview"),
  closeSql: document.querySelector("#closeSql"),
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
  const payload = await api("/api/queries");
  state.queries = payload.queries;
  renderQueryMenu();
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
  const usedNames = new Set();

  QUERY_GROUPS.forEach((group, index) => {
    const details = document.createElement("details");
    details.className = "menu-group";
    details.open = index < 2;

    const summary = document.createElement("summary");
    summary.textContent = group.title;
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

    details.appendChild(items);
    els.queryList.appendChild(details);
  });

  const uncategorized = state.queries.filter((query) => !usedNames.has(query.name));
  if (uncategorized.length > 0) {
    const details = document.createElement("details");
    details.className = "menu-group";
    details.open = true;
    const summary = document.createElement("summary");
    summary.textContent = "Other";
    const items = document.createElement("div");
    items.className = "menu-items";
    uncategorized.forEach((query) => items.appendChild(createQueryButton(query, "Other")));
    details.append(summary, items);
    els.queryList.appendChild(details);
  }
}

function createQueryButton(query, groupTitle) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "query-item";
  button.dataset.name = query.name;
  button.dataset.group = groupTitle;
  button.innerHTML = `<strong>${escapeHtml(query.title)}</strong><span>${escapeHtml(query.description)}</span>`;
  button.addEventListener("click", () => selectAndRunQuery(query.name, groupTitle));
  return button;
}

async function selectAndRunQuery(name, groupTitle) {
  setActiveQuery(name, groupTitle);
  if (state.connected) {
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
  document.querySelectorAll(".query-item").forEach((item) => {
    item.classList.toggle("active", item.dataset.name === name);
  });
  els.activeGroup.textContent = groupTitle;
  els.title.textContent = state.activeQuery.title;
  els.description.textContent = state.activeQuery.description;
  els.viewSql.disabled = false;
  els.runQuery.disabled = !state.connected;
  els.rowCount.textContent = "0";
  els.columnCount.textContent = "0";
  els.exportCsv.disabled = true;
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  renderEmptyTable("Loading section data...");
  clearMessage(els.message);
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
  els.runQuery.disabled = true;
  els.runQuery.textContent = "Running...";
  try {
    const payload = await api("/api/run-query", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        queryName: state.activeQuery.name,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    state.columns = resultSet.columns || [];
    state.rows = resultSet.rows || [];
    renderResults();
    clearMessage(els.message);
  } catch (error) {
    showMessage(els.message, error.message, "error");
  } finally {
    els.runQuery.disabled = !state.connected;
    els.runQuery.textContent = "Run";
  }
}

async function viewActiveSql() {
  if (!state.activeQuery) return;
  const payload = await api(`/api/query-sql?name=${encodeURIComponent(state.activeQuery.name)}`);
  els.sqlPreview.textContent = payload.sql;
  els.sqlDialog.showModal();
}

function renderResults() {
  if (CARD_QUERIES.has(state.activeQuery?.name) && state.rows.length <= 1) {
    renderCards();
    return;
  }
  els.message.classList.remove("hidden");
  els.summary.classList.remove("hidden");
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
  els.summary.classList.add("hidden");
  els.tableWrap.classList.add("hidden");
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
  const configuredFields = new Set(configured.flatMap((group) => group.fields));
  const remaining = state.columns.filter((column) => !configuredFields.has(column));
  if (remaining.length === 0) return configured;
  return [...configured, { title: "Other", fields: remaining }];
}

function renderTable() {
  const filter = els.filterText.value.trim().toLowerCase();
  const rows = filter
    ? state.rows.filter((row) =>
        state.columns.some((column) => String(row[column] ?? "").toLowerCase().includes(filter)),
      )
    : state.rows;

  els.rowCount.textContent = String(rows.length);
  els.columnCount.textContent = String(state.columns.length);
  els.exportCsv.disabled = rows.length === 0;
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");

  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = "";

  if (state.columns.length === 0) {
    renderEmptyTable("No columns to display.");
    return;
  }

  const headRow = document.createElement("tr");
  state.columns.forEach((column) => {
    const th = document.createElement("th");
    th.textContent = column;
    headRow.appendChild(th);
  });
  thead.appendChild(headRow);

  if (rows.length === 0) {
    const td = document.createElement("td");
    td.className = "empty";
    td.colSpan = state.columns.length;
    td.textContent = "No rows to display.";
    const tr = document.createElement("tr");
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  rows.forEach((row) => {
    const tr = document.createElement("tr");
    state.columns.forEach((column) => {
      const td = document.createElement("td");
      td.textContent = row[column] ?? "";
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

function renderEmptyTable(message) {
  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = `<tr><td class="empty">${escapeHtml(message)}</td></tr>`;
}

function exportCsv() {
  const lines = [
    state.columns.map(csvValue).join(","),
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
    .replace(/\bGb\b/g, "GB")
    .replace(/\bMb\b/g, "MB")
    .replace(/\bSql\b/g, "SQL")
    .replace(/\bId\b/g, "ID");
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
els.runQuery.addEventListener("click", runActiveQuery);
els.viewSql.addEventListener("click", viewActiveSql);
els.exportCsv.addEventListener("click", exportCsv);
els.filterText.addEventListener("input", renderTable);
els.closeSql.addEventListener("click", () => els.sqlDialog.close());
els.changeConnection.addEventListener("click", goToConnection);
els.toggleSidebar.addEventListener("click", () => {
  els.appLayout.classList.toggle("sidebar-collapsed");
});

async function initializeApp() {
  updateAuthFields();
  loadConnectionDraft();
  await loadDefaultConnection();
  await loadQueries();
}

initializeApp().catch((error) => {
  showMessage(els.connectionMessage, error.message, "error");
});
