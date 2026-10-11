/**
 * QSB Documentation & Interactive Help Center
 * Comprehensive Operations Research Workbench Catalog & Interactive Tooling
 */

const familiesData = [
  {
    id: "lp",
    name: "Linear & Integer Programming",
    shortCode: "LP / ILP",
    category: "optimization",
    categoryName: "Optimization",
    tag: "Core Solver",
    description: "Two-phase revised simplex with exact bounds, tableau generation, sensitivity analysis (shadow prices, reduced costs, allowable ranges), and branch & bound for integer/binary variables.",
    algorithms: "Native Revised Simplex, Branch & Bound, HiGHS backend",
    cliCommand: "qsb solve model.lp_ --backend native",
    manualChapter: "Chapter 2 & 3: Linear & Integer Programming",
    jsonTemplate: `{
  "title": "Production Mix Problem",
  "sense": "maximize",
  "variableNames": ["x1", "x2"],
  "objectiveCoefficients": [50.0, 60.0],
  "constraints": [
    {
      "name": "Assembly",
      "coefficients": [2.0, 3.0],
      "relation": "<=",
      "rhs": 180.0
    },
    {
      "name": "Finishing",
      "coefficients": [3.0, 2.0],
      "relation": "<=",
      "rhs": 150.0
    }
  ],
  "lowerBounds": [0.0, 0.0],
  "upperBounds": [null, null],
  "variableTypes": ["continuous", "continuous"],
  "unrestrictedVariables": [false, false]
}`
  },
  {
    id: "gp",
    name: "Goal Programming",
    shortCode: "GP / IGP",
    category: "optimization",
    categoryName: "Optimization",
    tag: "Multi-Objective",
    description: "Multi-objective decision models with pre-emptive priority levels (P1, P2, ...) and deviational variables (d+, d-) to minimize goal target penalties.",
    algorithms: "Sequential Lexicographic Simplex, HiGHS backend",
    cliCommand: "qsb solve GP.GP_ --backend native",
    manualChapter: "Chapter 10: Advanced Optimization",
    jsonTemplate: `{
  "title": "Corporate Goal Hierarchy",
  "sense": "minimize",
  "priorityLevels": 3,
  "goals": [
    { "name": "Profit", "target": 50000.0, "priority": 1, "underPenalty": 1.0, "overPenalty": 0.0 },
    { "name": "Employment", "target": 120.0, "priority": 2, "underPenalty": 2.0, "overPenalty": 1.0 },
    { "name": "Overtime", "target": 40.0, "priority": 3, "underPenalty": 0.0, "overPenalty": 3.0 }
  ]
}`
  },
  {
    id: "qp",
    name: "Quadratic Programming",
    shortCode: "QP / IQP",
    category: "optimization",
    categoryName: "Optimization",
    tag: "Convex / Non-Convex",
    description: "Quadratic objective optimization with linear constraints. Tailored for Markowitz mean-variance portfolio selection and non-linear cost minimization.",
    algorithms: "Active-Set KKT Solver, HiGHS QP backend",
    cliCommand: "qsb solve QP.QP_ --backend native",
    manualChapter: "Chapter 10: Advanced Optimization",
    jsonTemplate: `{
  "title": "Markowitz Portfolio Optimization",
  "sense": "minimize",
  "quadraticMatrix": [
    [0.04, 0.01, 0.02],
    [0.01, 0.09, 0.03],
    [0.02, 0.03, 0.16]
  ],
  "linearCoefficients": [0.0, 0.0, 0.0],
  "constraints": [
    { "name": "Budget", "coefficients": [1.0, 1.0, 1.0], "relation": "=", "rhs": 1.0 },
    { "name": "Return", "coefficients": [0.10, 0.14, 0.20], "relation": ">=", "rhs": 0.12 }
  ]
}`
  },
  {
    id: "nlp",
    name: "Nonlinear Programming",
    shortCode: "NLP",
    category: "optimization",
    categoryName: "Optimization",
    tag: "Nonlinear",
    description: "General non-linear continuous objective functions and non-linear constraints solved using projected numerical gradients and boundary evaluations.",
    algorithms: "Projected Gradient, Karush-Kuhn-Tucker verification",
    cliCommand: "qsb solve NLP1.NL_ --backend native",
    manualChapter: "Chapter 10: Advanced Optimization",
    jsonTemplate: `{
  "title": "Nonlinear Cost Minimization",
  "sense": "minimize",
  "variables": ["x", "y"],
  "objectiveExpression": "2*x^2 + y^2 - 2*x*y + 20*x + 15*y",
  "constraints": [
    { "expression": "x + 2*y", "relation": ">=", "rhs": 10.0 }
  ],
  "startingPoint": [1.0, 1.0]
}`
  },
  {
    id: "networks",
    name: "Network Modeling & Flows",
    shortCode: "NET",
    category: "networks",
    categoryName: "Networks",
    tag: "Graph Theory",
    description: "Shortest Path (Dijkstra, Bellman-Ford), Minimum Spanning Tree (Kruskal, Prim), Maximum Flow (Edmonds-Karp), Minimum Cost Network Flow, Transportation, and Hungarian Assignment.",
    algorithms: "Dijkstra, Hungarian Method, Edmonds-Karp, Kruskal",
    cliCommand: "qsb solve SHTPATH.NE_ --backend native",
    manualChapter: "Chapter 4: Network Models",
    jsonTemplate: `{
  "kind": "SPP",
  "model": {
    "title": "Logistics Corridor Shortest Path",
    "nodes": ["Node1", "Node2", "Node3", "Node4", "Node5"],
    "arcs": [
      { "from": "Node1", "to": "Node2", "cost": 2.0 },
      { "from": "Node1", "to": "Node3", "cost": 9.0 },
      { "from": "Node2", "to": "Node4", "cost": 7.0 },
      { "from": "Node3", "to": "Node4", "cost": 10.0 },
      { "from": "Node4", "to": "Node5", "cost": 15.0 }
    ]
  }
}`
  },
  {
    id: "cpm",
    name: "Project Scheduling (PERT / CPM)",
    shortCode: "CPM / PERT",
    category: "planning",
    categoryName: "Planning",
    tag: "Operations",
    description: "Critical Path Method with early/late start/finish calculations, total/free float, and stochastic PERT 3-point estimates (optimistic, most likely, pessimistic) with project variance.",
    algorithms: "Forward/Backward Pass, Critical Path Identification, PERT Normal CDF",
    cliCommand: "qsb solve CPM.CP_ --backend native",
    manualChapter: "Chapter 8: Scheduling & Project Management",
    jsonTemplate: `{
  "title": "Facility Modernization Project",
  "activities": [
    { "name": "Site Prep", "optimistic": 3, "mostLikely": 5, "pessimistic": 7, "predecessors": [] },
    { "name": "Foundations", "optimistic": 4, "mostLikely": 6, "pessimistic": 14, "predecessors": ["Site Prep"] },
    { "name": "Framing", "optimistic": 2, "mostLikely": 4, "pessimistic": 6, "predecessors": ["Foundations"] },
    { "name": "Electrical", "optimistic": 3, "mostLikely": 5, "pessimistic": 9, "predecessors": ["Framing"] }
  ]
}`
  },
  {
    id: "inventory",
    name: "Inventory Control & Lot Sizing",
    shortCode: "INV",
    category: "planning",
    categoryName: "Planning",
    tag: "Supply Chain",
    description: "Classic EOQ, planned backorders, production lot sizing (EPQ), all-units quantity discounts, single-period stochastic Newsboy, and dynamic lot sizing (Wagner-Whitin, Silver-Meal, Part-Period).",
    algorithms: "Closed-form EOQ, Wagner-Whitin Dynamic Programming, Silver-Meal heuristic",
    cliCommand: "qsb solve EOQ.IT_ --backend native",
    manualChapter: "Chapter 5: Inventory Models",
    jsonTemplate: `{
  "kind": "eoq",
  "model": {
    "title": "Industrial Warehouse EOQ",
    "demand": 600.0,
    "setupCost": 50.0,
    "holdingCost": 60.0,
    "acquisitionCost": 300.0,
    "timeUnit": "year"
  }
}`
  },
  {
    id: "queuing",
    name: "Queuing Systems & Waiting Lines",
    shortCode: "QA",
    category: "uncertainty",
    categoryName: "Uncertainty",
    tag: "Stochastic",
    description: "Markovian waiting line models: M/M/1, M/M/s, M/M/s/K (finite buffer), and finite population M/M/s/∞/N. Calculates server utilization, mean queue length, waiting times, and economic trade-offs.",
    algorithms: "Steady-state Markovian birth-death balance equations",
    cliCommand: "qsb solve QUEUE1.QA_ --backend native",
    manualChapter: "Chapter 6: Queuing Theory",
    jsonTemplate: `{
  "kind": "mm1",
  "model": {
    "title": "Technical Service Desk",
    "arrivalRate": 2.0,
    "serviceRate": 3.0,
    "timeUnit": "hour",
    "idleServerCostPerTime": 200.0,
    "busyServerCostPerTime": 200.0,
    "customerWaitingCostPerTime": 50.0,
    "customerBeingServedCostPerTime": 50.0
  }
}`
  },
  {
    id: "forecasting",
    name: "Time Series & Forecasting",
    shortCode: "FC",
    category: "planning",
    categoryName: "Planning",
    tag: "Analytics",
    description: "Quantitative forecasting: Simple Moving Average, Weighted Moving Average, Single/Double Exponential Smoothing (Holt-Winters), and Ordinary Least Squares Linear Trend Regression with MAD, MSE, MAPE.",
    algorithms: "OLS Regression, Holt-Winters Smoothing, Error Metric Minimization",
    cliCommand: "qsb solve SALES.FC_ --backend native",
    manualChapter: "Chapter 7: Forecasting",
    jsonTemplate: `{
  "title": "Quarterly Demand Forecast",
  "method": "linearRegression",
  "historicalData": [120, 135, 148, 162, 175, 190, 205, 218],
  "forecastPeriods": 4
}`
  },
  {
    id: "scheduling",
    name: "Production Scheduling & Sequencing",
    shortCode: "JOB / FLOW",
    category: "production",
    categoryName: "Production",
    tag: "Shop Floor",
    description: "Sequencing n jobs across m machines. Flow shop optimization with Johnson's rule for 2 and 3 stages, and job shop priority dispatching (SPT, LPT, FCFS, EDD, Slack/OPN).",
    algorithms: "Johnson's Two-Stage Rule, Dispatching Rule Simulation",
    cliCommand: "qsb solve JOBSHOP.JO_ --backend native",
    manualChapter: "Chapter 8: Scheduling",
    jsonTemplate: `{
  "title": "Metal Fabrication Flow Shop",
  "jobs": [
    { "name": "Job A", "machineTimes": [4, 7] },
    { "name": "Job B", "machineTimes": [8, 3] },
    { "name": "Job C", "machineTimes": [6, 8] },
    { "name": "Job D", "machineTimes": [3, 5] }
  ]
}`
  },
  {
    id: "ap",
    name: "Aggregate Production Planning",
    shortCode: "AP",
    category: "production",
    categoryName: "Production",
    tag: "Operations",
    description: "Multi-period aggregate production strategy optimizing regular time, overtime, subcontracting, inventory accumulation, lost sales, and workforce leveling/chase policies.",
    algorithms: "Transportation Tableau LP formulation, Simplex / HiGHS",
    cliCommand: "qsb solve APLP.AP_ --backend native",
    manualChapter: "Chapter 11: Production Planning",
    jsonTemplate: `{
  "title": "Six-Month Aggregate Plan",
  "periods": 6,
  "demands": [1000, 1200, 1500, 1800, 1400, 1100],
  "regularCapacity": 1100,
  "overtimeCapacity": 300,
  "subcontractCapacity": 400,
  "regularCost": 20.0,
  "overtimeCost": 30.0,
  "subcontractCost": 35.0,
  "holdingCost": 2.0
}`
  },
  {
    id: "mrp",
    name: "Material Requirements Planning",
    shortCode: "MRP",
    category: "production",
    categoryName: "Production",
    tag: "BOM Explosion",
    description: "Multi-level Bill of Materials (BOM) explosion, gross-to-net requirements scheduling, lead-time offsetting, and scheduled order receipts generation across planning horizons.",
    algorithms: "Low-level tree traversal, Time-phased order release",
    cliCommand: "qsb solve QSB.MR_ --backend native",
    manualChapter: "Chapter 11: Production Planning & MRP",
    jsonTemplate: `{
  "title": "Bicycle Assembly BOM",
  "endItem": "Bicycle",
  "masterSchedule": [ { "period": 4, "quantity": 100 }, { "period": 6, "quantity": 150 } ],
  "billOfMaterials": [
    { "parent": "Bicycle", "child": "Frame", "quantity": 1, "leadTime": 1, "onHand": 20 },
    { "parent": "Bicycle", "child": "Wheel Assembly", "quantity": 2, "leadTime": 2, "onHand": 50 }
  ]
}`
  },
  {
    id: "facilities",
    name: "Facility Location & Line Balancing",
    shortCode: "FLL",
    category: "production",
    categoryName: "Production",
    tag: "Industrial",
    description: "Facility location using continuous Center of Gravity and Weber distance minimization. Assembly line balancing with Ranked Positional Weight (Helgeson-Birnie) and cycle time optimization.",
    algorithms: "Center of Gravity, Ranked Positional Weight, COMSOAL",
    cliCommand: "qsb solve LOCATION.FL_ --backend native",
    manualChapter: "Chapter 12: Facilities & Layout",
    jsonTemplate: `{
  "title": "Regional Distribution Center Location",
  "method": "centerOfGravity",
  "destinations": [
    { "name": "City Alpha", "x": 10.0, "y": 20.0, "volume": 500 },
    { "name": "City Beta", "x": 40.0, "y": 60.0, "volume": 800 },
    { "name": "City Gamma", "x": 70.0, "y": 15.0, "volume": 300 }
  ]
}`
  },
  {
    id: "markov",
    name: "Markov Chains & Processes",
    shortCode: "MKP",
    category: "uncertainty",
    categoryName: "Uncertainty",
    tag: "Stochastic",
    description: "Discrete-time Markov chains with stationary transition matrices. Calculates n-step transitions, steady-state stationary probabilities, mean first passage times, and absorption probabilities.",
    algorithms: "Normalized Linear System Solution, Fundamental Matrix",
    cliCommand: "qsb solve MKP1.MK_ --backend native",
    manualChapter: "Chapter 13: Markov Processes",
    jsonTemplate: `{
  "title": "Customer Brand Switching Model",
  "states": ["Brand A", "Brand B", "Brand C"],
  "transitionMatrix": [
    [0.70, 0.20, 0.10],
    [0.15, 0.75, 0.10],
    [0.10, 0.20, 0.70]
  ],
  "initialDistribution": [0.33, 0.33, 0.34]
}`
  },
  {
    id: "quality",
    name: "Quality Control & Sampling",
    shortCode: "QC / ASA",
    category: "uncertainty",
    categoryName: "Uncertainty",
    tag: "Quality",
    description: "Statistical Process Control (SPC): X-bar, R, S, p, np, c, u control charts. Acceptance sampling with Operating Characteristic (OC) curves (Binomial, Poisson, Hypergeometric) and AOQL/ASN.",
    algorithms: "ASTM / ISO 3-Sigma Limits, Binomial & Poisson OC Curves",
    cliCommand: "qsb solve VARIABLE.QC_ --backend native",
    manualChapter: "Chapter 14: Quality Control & Sampling",
    jsonTemplate: `{
  "title": "Shaft Diameter X-bar Chart",
  "type": "xBarR",
  "subgroupSize": 5,
  "samples": [
    [10.02, 10.05, 9.98, 10.01, 10.04],
    [9.99, 10.02, 10.01, 10.03, 10.00],
    [10.04, 10.07, 10.03, 10.05, 10.01]
  ]
}`
  },
  {
    id: "decision",
    name: "Decision Analysis & Dynamic Programming",
    shortCode: "DA / DP",
    category: "uncertainty",
    categoryName: "Uncertainty",
    tag: "Decision Theory",
    description: "Decision making under uncertainty (Maximax, Maximin, Hurwicz, Minimax Regret), EMV, EVPI, Decision Trees, Bayesian posterior revision, zero-sum game theory, and Bellman dynamic programming.",
    algorithms: "Backward Induction, Bayes Theorem, Bellman Recursion",
    cliCommand: "qsb solve PAYOFF.DA_ --backend native",
    manualChapter: "Chapter 15: Decision Analysis & DP",
    jsonTemplate: `{
  "title": "Plant Expansion Payoff Matrix",
  "decisionAlternatives": ["Build Large Plant", "Build Small Plant", "Do Nothing"],
  "statesOfNature": ["High Demand", "Moderate Demand", "Low Demand"],
  "probabilities": [0.40, 0.40, 0.20],
  "payoffs": [
    [200000, 100000, -120000],
    [100000, 80000, -20000],
    [0, 0, 0]
  ]
}`
  }
];

// Initialize DOM elements
document.addEventListener("DOMContentLoaded", () => {
  renderCatalog(familiesData);
  setupFilters();
  setupSearch();
  setupTabs();
  setupModal();
});

// Render Catalog Cards
function renderCatalog(items) {
  const container = document.getElementById("catalog-grid");
  if (!container) return;

  if (items.length === 0) {
    container.innerHTML = `
      <div style="grid-column: 1 / -1; text-align: center; padding: 48px; color: var(--text-muted);">
        <p style="font-size: 1.1rem; margin-bottom: 8px;">No model families found matching your query.</p>
        <p style="font-size: 0.9rem;">Try clearing the search or choosing a different category filter.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = items.map(item => `
    <article class="family-card" data-id="${item.id}">
      <div class="card-top">
        <div class="card-header-line">
          <span class="card-cat">${item.categoryName}</span>
          <span class="card-tag">${item.tag}</span>
        </div>
        <h3 class="card-title">${item.name}</h3>
        <p class="card-desc">${item.description}</p>
      </div>
      <div class="card-bottom">
        <span class="card-meta">
          Code: <strong class="meta-char">${item.shortCode}</strong>
        </span>
        <button class="btn-card" onclick="openModelModal('${item.id}')">
          Inspect Model & JSON
        </button>
      </div>
    </article>
  `).join("");
}

// Category Pill Filtering
function setupFilters() {
  const pills = document.querySelectorAll(".pill-btn");
  pills.forEach(pill => {
    pill.addEventListener("click", () => {
      pills.forEach(p => p.classList.remove("active"));
      pill.classList.add("active");

      const category = pill.getAttribute("data-category");
      const searchQuery = document.getElementById("search-input")?.value.toLowerCase().trim() || "";

      filterCatalog(category, searchQuery);
    });
  });
}

// Search Filtering
function setupSearch() {
  const searchInput = document.getElementById("search-input");
  if (!searchInput) return;

  searchInput.addEventListener("input", (e) => {
    const query = e.target.value.toLowerCase().trim();
    const activeCategory = document.querySelector(".pill-btn.active")?.getAttribute("data-category") || "all";
    filterCatalog(activeCategory, query);
  });
}

function filterCatalog(category, query) {
  let filtered = familiesData;

  if (category && category !== "all") {
    filtered = filtered.filter(f => f.category === category);
  }

  if (query) {
    filtered = filtered.filter(f =>
      f.name.toLowerCase().includes(query) ||
      f.shortCode.toLowerCase().includes(query) ||
      f.description.toLowerCase().includes(query) ||
      f.algorithms.toLowerCase().includes(query) ||
      f.categoryName.toLowerCase().includes(query)
    );
  }

  renderCatalog(filtered);
}

// Quickstart Tab Switching
function setupTabs() {
  const tabButtons = document.querySelectorAll(".tab-btn");
  const tabContents = document.querySelectorAll(".tab-content");

  tabButtons.forEach(btn => {
    btn.addEventListener("click", () => {
      const targetId = btn.getAttribute("data-tab");

      tabButtons.forEach(b => b.classList.remove("active"));
      tabContents.forEach(c => c.classList.remove("active"));

      btn.classList.add("active");
      const targetContent = document.getElementById(targetId);
      if (targetContent) targetContent.classList.add("active");
    });
  });
}

// Modal Drawer Setup
function setupModal() {
  const overlay = document.getElementById("modal-overlay");
  const closeBtn = document.getElementById("modal-close");

  if (overlay) {
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) closeModal();
    });
  }

  if (closeBtn) {
    closeBtn.addEventListener("click", closeModal);
  }

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeModal();
  });
}

function openModelModal(familyId) {
  const item = familiesData.find(f => f.id === familyId);
  if (!item) return;

  const overlay = document.getElementById("modal-overlay");
  const title = document.getElementById("modal-title");
  const body = document.getElementById("modal-body-content");

  if (!overlay || !title || !body) return;

  title.innerText = `${item.name} (${item.shortCode})`;

  body.innerHTML = `
    <div style="margin-bottom: 20px;">
      <div style="display: flex; gap: 8px; margin-bottom: 12px; align-items: center;">
        <span class="card-cat" style="font-size: 0.82rem;">${item.categoryName}</span>
        <span style="color: var(--text-muted);">&bull;</span>
        <span style="color: var(--accent-emerald); font-size: 0.85rem; font-weight: 600;">${item.manualChapter}</span>
      </div>
      <p style="color: var(--text-secondary); font-size: 0.95rem; margin-bottom: 16px;">
        ${item.description}
      </p>
      <div style="background: rgba(255, 255, 255, 0.04); border: 1px solid var(--border-color); border-radius: 10px; padding: 12px 16px; margin-bottom: 18px;">
        <span style="font-size: 0.8rem; text-transform: uppercase; color: var(--text-muted); font-weight: 700; display: block; margin-bottom: 4px;">Solvers & Guarantees</span>
        <span style="font-size: 0.92rem; color: #f1f5f9;">${item.algorithms}</span>
      </div>
    </div>

    <div style="margin-bottom: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <span style="font-size: 0.85rem; font-weight: 700; color: var(--text-primary); text-transform: uppercase;">CLI Command</span>
        <button class="copy-btn" onclick="copyTextToClipboard('${item.cliCommand.replace(/'/g, "\\'")}', 'CLI command copied!')">Copy Command</button>
      </div>
      <div class="code-block" style="padding: 12px 16px;">
        <code>${item.cliCommand}</code>
      </div>
    </div>

    <div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <span style="font-size: 0.85rem; font-weight: 700; color: var(--text-primary); text-transform: uppercase;">Normalized Model JSON Template</span>
        <button class="copy-btn" onclick="copyTextToClipboard(decodeURIComponent('${encodeURIComponent(item.jsonTemplate)}'), 'JSON template copied!')">Copy JSON</button>
      </div>
      <div class="code-block" style="max-height: 280px; overflow-y: auto;">
        <pre><code>${escapeHtml(item.jsonTemplate)}</code></pre>
      </div>
    </div>
  `;

  overlay.classList.add("open");
  document.body.style.overflow = "hidden";
}

function closeModal() {
  const overlay = document.getElementById("modal-overlay");
  if (overlay) overlay.classList.remove("open");
  document.body.style.overflow = "";
}

// Copy to Clipboard Utility with Toast Notification
function copyTextToClipboard(text, message = "Copied to clipboard!") {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(() => {
      showToast(message);
    }).catch(() => {
      fallbackCopy(text, message);
    });
  } else {
    fallbackCopy(text, message);
  }
}

function fallbackCopy(text, message) {
  const textArea = document.createElement("textarea");
  textArea.value = text;
  textArea.style.position = "fixed";
  textArea.style.left = "-9999px";
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  try {
    document.execCommand("copy");
    showToast(message);
  } catch (err) {
    console.error("Copy failed", err);
  }
  document.body.removeChild(textArea);
}

// Floating Toast Notification
function showToast(message) {
  let container = document.querySelector(".toast-container");
  if (!container) {
    container = document.createElement("div");
    container.className = "toast-container";
    document.body.appendChild(container);
  }

  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
      <path d="M20 6L9 17l-5-5"/>
    </svg>
    <span>${message}</span>
  `;

  container.appendChild(toast);

  // Trigger animation
  requestAnimationFrame(() => {
    toast.classList.add("show");
  });

  setTimeout(() => {
    toast.classList.remove("show");
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }, 2600);
}

function escapeHtml(string) {
  return String(string)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
