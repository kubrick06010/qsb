enum SampleModels {
    static let linearProgramJSON = """
    {
      "constraints" : [
        {
          "coefficients" : [
            2,
            3
          ],
          "name" : "C1",
          "relation" : "<=",
          "rhs" : 180
        },
        {
          "coefficients" : [
            3,
            2
          ],
          "name" : "C2",
          "relation" : "<=",
          "rhs" : 150
        }
      ],
      "lowerBounds" : [
        0,
        0
      ],
      "objectiveCoefficients" : [
        50,
        60
      ],
      "sense" : "maximize",
      "title" : "LP Sample Problem",
      "upperBounds" : [
        null,
        null
      ],
      "variableNames" : [
        "X1",
        "X2"
      ],
      "variableTypes" : [
        "continuous",
        "continuous"
      ]
    }
    """

    static let integerProgramJSON = """
    {
      "constraints" : [
        {
          "coefficients" : [
            6,
            3
          ],
          "name" : "C1",
          "relation" : ">=",
          "rhs" : 200
        },
        {
          "coefficients" : [
            3,
            5
          ],
          "name" : "C2",
          "relation" : ">=",
          "rhs" : 180
        }
      ],
      "lowerBounds" : [
        0,
        0
      ],
      "objectiveCoefficients" : [
        2.5,
        2
      ],
      "sense" : "minimize",
      "title" : "ILP Sample Problem",
      "upperBounds" : [
        null,
        null
      ],
      "variableNames" : [
        "X1",
        "X2"
      ],
      "variableTypes" : [
        "integer",
        "integer"
      ]
    }
    """

    static let travelingSalespersonJSON = """
    {
      "kind" : "TSP",
      "model" : {
        "arcs" : [
          {
            "cost" : 100,
            "from" : "LA",
            "to" : "DEV"
          },
          {
            "cost" : 150,
            "from" : "LA",
            "to" : "HOU"
          },
          {
            "cost" : 300,
            "from" : "LA",
            "to" : "CMH"
          },
          {
            "cost" : 500,
            "from" : "LA",
            "to" : "NY"
          },
          {
            "cost" : 100,
            "from" : "DEV",
            "to" : "LA"
          },
          {
            "cost" : 160,
            "from" : "DEV",
            "to" : "HOU"
          },
          {
            "cost" : 150,
            "from" : "DEV",
            "to" : "DAL"
          },
          {
            "cost" : 300,
            "from" : "DEV",
            "to" : "CMH"
          },
          {
            "cost" : 150,
            "from" : "HOU",
            "to" : "LA"
          },
          {
            "cost" : 160,
            "from" : "HOU",
            "to" : "DEV"
          },
          {
            "cost" : 100,
            "from" : "HOU",
            "to" : "DAL"
          },
          {
            "cost" : 260,
            "from" : "HOU",
            "to" : "CMH"
          },
          {
            "cost" : 290,
            "from" : "HOU",
            "to" : "NY"
          },
          {
            "cost" : 150,
            "from" : "DAL",
            "to" : "DEV"
          },
          {
            "cost" : 100,
            "from" : "DAL",
            "to" : "HOU"
          },
          {
            "cost" : 240,
            "from" : "DAL",
            "to" : "CMH"
          },
          {
            "cost" : 360,
            "from" : "DAL",
            "to" : "NY"
          },
          {
            "cost" : 300,
            "from" : "CMH",
            "to" : "LA"
          },
          {
            "cost" : 300,
            "from" : "CMH",
            "to" : "DEV"
          },
          {
            "cost" : 260,
            "from" : "CMH",
            "to" : "HOU"
          },
          {
            "cost" : 240,
            "from" : "CMH",
            "to" : "DAL"
          },
          {
            "cost" : 200,
            "from" : "CMH",
            "to" : "NY"
          },
          {
            "cost" : 500,
            "from" : "NY",
            "to" : "LA"
          },
          {
            "cost" : 290,
            "from" : "NY",
            "to" : "HOU"
          },
          {
            "cost" : 360,
            "from" : "NY",
            "to" : "DAL"
          },
          {
            "cost" : 200,
            "from" : "NY",
            "to" : "CMH"
          }
        ],
        "nodes" : [
          "LA",
          "DEV",
          "HOU",
          "DAL",
          "CMH",
          "NY"
        ],
        "title" : "TSP"
      }
    }
    """

    static let facilityLayoutJSON = """
    {
      "kind" : "layout",
      "model" : {
        "columnCount" : 6,
        "departments" : [
          {
            "fixed" : false,
            "flowUnitCosts" : [null, 1, 10],
            "id" : 1,
            "initialLayout" : [
              {
                "endColumn" : 2,
                "endRow" : 1,
                "startColumn" : 1,
                "startRow" : 1
              }
            ],
            "name" : "A"
          },
          {
            "fixed" : false,
            "flowUnitCosts" : [1, null, 1],
            "id" : 2,
            "initialLayout" : [
              {
                "endColumn" : 4,
                "endRow" : 1,
                "startColumn" : 3,
                "startRow" : 1
              }
            ],
            "name" : "B"
          },
          {
            "fixed" : false,
            "flowUnitCosts" : [10, 1, null],
            "id" : 3,
            "initialLayout" : [
              {
                "endColumn" : 6,
                "endRow" : 1,
                "startColumn" : 5,
                "startRow" : 1
              }
            ],
            "name" : "C"
          }
        ],
        "objective" : "MIN",
        "rowCount" : 1,
        "title" : "Facility Layout Sample"
      }
    }
    """

    static let facilityLocationJSON = """
    {
      "kind" : "location",
      "model" : {
        "distanceMeasure" : "rectilinear",
        "facilities" : [
          {
            "id" : 1,
            "interactionCosts" : [null, null, null],
            "isNew" : false,
            "name" : "Warehouse West",
            "x" : 0,
            "y" : 0
          },
          {
            "id" : 2,
            "interactionCosts" : [null, null, null],
            "isNew" : false,
            "name" : "Warehouse East",
            "x" : 10,
            "y" : 0
          },
          {
            "id" : 3,
            "interactionCosts" : [2, 1, null],
            "isNew" : true,
            "name" : "New Depot",
            "x" : null,
            "y" : null
          }
        ],
        "objective" : "MIN",
        "title" : "Two-Warehouse Location"
      }
    }
    """

    static let lineBalancingJSON = """
    {
      "kind" : "lineBalancing",
      "model" : {
        "cycleTime" : 7,
        "tasks" : [
          { "id" : 1, "isolated" : false, "name" : "Prepare", "successorIDs" : [3], "time" : 4 },
          { "id" : 2, "isolated" : false, "name" : "Inspect", "successorIDs" : [3], "time" : 3 },
          { "id" : 3, "isolated" : false, "name" : "Assemble", "successorIDs" : [], "time" : 5 }
        ],
        "timeUnit" : "minute",
        "title" : "Compact Assembly Line"
      }
    }
    """

    static let economicOrderQuantityJSON = """
    {
      "kind" : "eoq",
      "model" : {
        "acquisitionCost" : 10,
        "demand" : 1000,
        "holdingCost" : 2,
        "leadTime" : 0.02,
        "setupCost" : 50,
        "timeUnit" : "year",
        "title" : "EOQ Sample"
      }
    }
    """

    static let boundedKnapsackJSON = """
    {
      "kind" : "boundedKnapsack",
      "model" : {
        "capacity" : 20,
        "items" : [
          { "available" : 5, "capacityRequired" : 10, "name" : "A", "returnPerUnit" : 8 },
          { "available" : 3, "capacityRequired" : 6, "name" : "B", "returnPerUnit" : 10 },
          { "available" : 4, "capacityRequired" : 3, "name" : "C", "returnPerUnit" : 4 },
          { "available" : 2, "capacityRequired" : 5, "name" : "D", "returnPerUnit" : 7 }
        ],
        "title" : "Bounded Knapsack Sample"
      }
    }
    """

    static let linearTrendForecastJSON = """
    {
      "method" : "linearTrend",
      "model" : {
        "kind" : "timeSeries",
        "model" : {
          "observations" : [
            { "label" : "1", "value" : 398 },
            { "label" : "2", "value" : 395 },
            { "label" : "3", "value" : 410 },
            { "label" : "4", "value" : 425 },
            { "label" : "5", "value" : 450 },
            { "label" : "6", "value" : 465 }
          ],
          "timeUnit" : "month",
          "title" : "Monthly Sales Forecast",
          "valueName" : "Sales"
        }
      },
      "periodsAhead" : 2
    }
    """

    static let payoffAnalysisJSON = """
    {
      "kind" : "payoff",
      "model" : {
        "decisions" : ["Advertise", "Do Nothing", "Pricing"],
        "indicatorLikelihoods" : [[0.6, 0.3, 0.2], [0.2, 0.3, 0.55], [0.2, 0.4, 0.25]],
        "indicators" : ["Favorable", "Unfavorable", "Neutral"],
        "payoffs" : [[100000, 52000, 30000], [35000, -10000, -30000], [84000, 55000, 40000]],
        "priorProbabilities" : [0.2, 0.5, 0.3],
        "states" : ["High", "Medium", "Low"],
        "title" : "Payoff Analysis Sample"
      }
    }
    """

    static let decisionTreeJSON = """
    {
      "kind" : "decisionTree",
      "model" : {
        "nodes" : [
          { "childIDs" : [2, 3], "id" : 1, "kind" : "decision", "name" : "Launch Decision" },
          { "childIDs" : [4, 5], "id" : 2, "kind" : "chance", "name" : "Launch" },
          { "childIDs" : [6, 7], "id" : 3, "kind" : "chance", "name" : "License" },
          { "childIDs" : [], "id" : 4, "kind" : "terminal", "name" : "Strong Demand", "payoff" : 120000, "probability" : 0.6 },
          { "childIDs" : [], "id" : 5, "kind" : "terminal", "name" : "Weak Demand", "payoff" : -20000, "probability" : 0.4 },
          { "childIDs" : [], "id" : 6, "kind" : "terminal", "name" : "High Royalty", "payoff" : 55000, "probability" : 0.7 },
          { "childIDs" : [], "id" : 7, "kind" : "terminal", "name" : "Low Royalty", "payoff" : 35000, "probability" : 0.3 }
        ],
        "rootID" : 1,
        "title" : "Decision Tree Sample"
      }
    }
    """

    static let mm1QueueJSON = """
    {
      "kind" : "mm1",
      "model" : {
        "arrivalRate" : 2,
        "busyServerCostPerTime" : 40,
        "customerBeingServedCostPerTime" : 20,
        "customerWaitingCostPerTime" : 100,
        "idleServerCostPerTime" : 15,
        "serviceRate" : 3,
        "timeUnit" : "hour",
        "title" : "Service Desk Queue"
      }
    }
    """

    static let simulationJSON = """
    {
      "components" : [
        {
          "batchSize" : { "kind" : "constant", "parameters" : [1] },
          "interarrivalTime" : { "kind" : "exponential", "parameters" : [1.2] },
          "kind" : "C",
          "name" : "Customer",
          "routes" : [{ "probability" : 1, "target" : "Queue", "transferTime" : 0 }],
          "serviceRules" : []
        },
        {
          "kind" : "Q",
          "name" : "Queue",
          "queueCapacity" : 100,
          "queueDiscipline" : "FIFO",
          "routes" : [{ "probability" : 1, "target" : "Clerk", "transferTime" : 0 }],
          "serviceRules" : []
        },
        {
          "kind" : "S",
          "name" : "Clerk",
          "routes" : [],
          "serviceRules" : [{ "distribution" : { "kind" : "exponential", "parameters" : [1] }, "entityType" : "Customer" }]
        }
      ],
      "representation" : "matrix",
      "timeUnit" : "hour",
      "title" : "Service Desk Simulation"
    }
    """

    static let quadraticProgrammingJSON = """
    {
      "constraints" : [],
      "linearCoefficients" : [-4],
      "lowerBounds" : [0],
      "quadraticMatrix" : [[1]],
      "sense" : "minimize",
      "title" : "Convex Quadratic Sample",
      "upperBounds" : [10],
      "variableNames" : ["x"],
      "variableTypes" : ["continuous"]
    }
    """

    static let nonlinearProgrammingJSON = """
    {
      "constraints" : [],
      "lowerBounds" : [0],
      "normalizedStrictInequalities" : false,
      "objectiveExpression" : "(x - 3)^2",
      "sense" : "minimize",
      "title" : "Bounded Nonlinear Sample",
      "upperBounds" : [10],
      "variableNames" : ["x"]
    }
    """

    static let markovJSON = """
    {
      "model" : {
        "initialProbabilities" : [1, 0],
        "stateCosts" : [5, 1],
        "states" : ["Busy", "Idle"],
        "title" : "Two-State Markov Sample",
        "transitionMatrix" : [[0.7, 0.3], [0.2, 0.8]]
      },
      "periods" : 8
    }
    """

    static let goalProgrammingJSON = """
    {
      "constraints" : [
        { "coefficients" : [1, 1], "name" : "Capacity", "relation" : "<=", "rhs" : 10 }
      ],
      "goals" : [
        { "coefficients" : [1, 0], "name" : "Primary Output", "sense" : "maximize" },
        { "coefficients" : [0, 1], "name" : "Secondary Output", "sense" : "maximize" }
      ],
      "lowerBounds" : [0, 0],
      "title" : "Lexicographic Goal Sample",
      "upperBounds" : [10, 10],
      "variableNames" : ["Primary", "Secondary"],
      "variableTypes" : ["continuous", "continuous"]
    }
    """

    static let aggregatePlanningJSON = """
    {
      "backorderCost" : [8, 8, 8],
      "capacityIsPerWorker" : false,
      "capacityRequirementPerUnit" : [1, 1, 1],
      "capacityUnit" : "units",
      "demand" : [80, 120, 100],
      "dismissalCost" : [0, 0, 0],
      "hiringCost" : [0, 0, 0],
      "initialInventory" : 0,
      "initialWorkforce" : null,
      "inventoryHoldingCost" : [0.5, 0.5, 0.5],
      "maximumBackorder" : [0, 0, 0],
      "maximumInventory" : [50, 50, 50],
      "maximumSubcontracting" : [20, 20, 20],
      "maximumWorkforce" : [null, null, null],
      "method" : 1,
      "minimumInventory" : [0, 0, 0],
      "minimumWorkforce" : [0, 0, 0],
      "otherUnitProductionCost" : [0, 0, 0],
      "overtimeCapacity" : [30, 30, 30],
      "overtimeCost" : [3, 3, 3],
      "periodNames" : ["Jan", "Feb", "Mar"],
      "regularCapacity" : [100, 100, 100],
      "regularCost" : [2, 2, 2],
      "subcontractingCost" : [4, 4, 4],
      "title" : "Three-Period Production Plan",
      "undertimeCost" : [0, 0, 0],
      "workforceUnit" : "workers"
    }
    """

    static let materialRequirementsPlanningJSON = """
    {
      "billsOfMaterial" : [
        {
          "components" : [{ "itemIdentifier" : "COMP", "quantityPerParent" : 2 }],
          "parentIdentifier" : "FINAL"
        }
      ],
      "bucketNames" : ["Overdue", "Week 1", "Week 2", "Week 3", "Week 4"],
      "items" : [
        {
          "annualDemand" : 780,
          "annualHoldingCost" : 1,
          "capacity" : [null, 50, 50, 50, 50],
          "description" : "Finished assembly",
          "identifier" : "FINAL",
          "initialOnHand" : 0,
          "leadTime" : 1,
          "levelCode" : "0",
          "lotSizingLookahead" : null,
          "lotSizingRule" : "LFL",
          "materialType" : "Assembly",
          "orderingCost" : 20,
          "safetyStock" : 0,
          "scheduledReceipts" : [0, 0, 0, 0, 0],
          "sourceCode" : "M",
          "unit" : "unit",
          "unitCost" : 25
        },
        {
          "annualDemand" : 1560,
          "annualHoldingCost" : 0.5,
          "capacity" : [null, null, null, null, null],
          "description" : "Purchased component",
          "identifier" : "COMP",
          "initialOnHand" : 20,
          "leadTime" : 1,
          "levelCode" : "1",
          "lotSizingLookahead" : null,
          "lotSizingRule" : "LFL",
          "materialType" : "Component",
          "orderingCost" : 10,
          "safetyStock" : 10,
          "scheduledReceipts" : [0, 0, 0, 0, 0],
          "sourceCode" : "P",
          "unit" : "piece",
          "unitCost" : 4
        }
      ],
      "masterProductionSchedule" : {
        "FINAL" : [0, 20, 0, 30, 10]
      },
      "periodsPerYear" : 52,
      "timeUnit" : "Week",
      "title" : "Four-Week Assembly Plan"
    }
    """

    static let acceptanceSamplingJSON = """
    {
      "kind" : "single",
      "model" : {
        "acceptableQualityLevel" : 0.02,
        "acceptanceNumber" : 2,
        "economics" : {
          "consumerDefectiveCost" : 12,
          "lotSize" : 500,
          "producerDefectiveCost" : 4,
          "unitInspectionCost" : 0.5,
          "unitSamplingCost" : 1
        },
        "nominalConsumerRisk" : 0.1,
        "nominalProducerRisk" : 0.05,
        "rejectableQualityLevel" : 0.08,
        "sampleSize" : 60,
        "title" : "Incoming Lot Inspection"
      }
    }
    """

    static let qualityControlJSON = """
    {
      "kind" : "cChart",
      "model" : {
        "characteristic" : "Defects",
        "counts" : [4, 5, 3, 6, 4, 5, 18, 4, 3, 5],
        "title" : "Weekly Defect Count"
      }
    }
    """

    static let projectSchedulingJSON = """
    {
      "kind" : "CPM",
      "model" : {
        "activities" : [
          { "crashCost" : 140, "crashTime" : 2, "name" : "A", "normalCost" : 100, "normalTime" : 4, "predecessors" : [] },
          { "crashCost" : 100, "crashTime" : 2, "name" : "B", "normalCost" : 80, "normalTime" : 3, "predecessors" : [] },
          { "crashCost" : 180, "crashTime" : 3, "name" : "C", "normalCost" : 120, "normalTime" : 5, "predecessors" : ["A"] },
          { "crashCost" : 90, "crashTime" : 1, "name" : "D", "normalCost" : 60, "normalTime" : 2, "predecessors" : ["B", "C"] }
        ],
        "timeUnit" : "day",
        "title" : "Product Launch CPM"
      }
    }
    """
}
