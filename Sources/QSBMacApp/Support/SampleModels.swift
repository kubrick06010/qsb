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
}
