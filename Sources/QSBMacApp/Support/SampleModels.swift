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
}
