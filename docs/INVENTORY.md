# Inventory

The inventory module supports legacy WinQSB economic order quantity (EOQ),
all-units quantity discount EOQ, newsboy, and finite-horizon lot-sizing files.

Supported input:

- Legacy WinQSB `ITS ... 0 0` EOQ files.
- Compressed `SZDD` fixtures such as `reference/winqsb/EOQ.IT_`.
- Demand, setup/order cost, holding cost, optional acquisition cost, optional
  replenishment rate, optional lead time, and optional known order quantity.

The solver computes the closed-form EOQ, cycle count, cycle length, cost
breakdown, and a known-quantity comparison when the legacy file provides one.

Run:

```sh
qsb solve-eoq reference/winqsb/EOQ.IT_
```

Example output:

```text
QSB209
timeUnit: year
economicOrderQuantity: 31.622777
cycleCount: 18.973666
cycleLength: 0.052705
optimum.totalRelevantCost: 1897.366596
knownQuantity.totalRelevantCost: 2300
```

## Quantity Discounts

Supported input:

- Legacy WinQSB `ITS ... 1 1` quantity-discount EOQ files.
- Compressed `SZDD` fixtures such as `reference/winqsb/DISCOUNT.IT_`.
- Base unit acquisition cost and percentage discount breaks by minimum order
  quantity.

The solver evaluates the base EOQ tier and each discount tier, then chooses the
lowest total cost including acquisition, setup, and holding costs.

Run:

```sh
qsb solve-discount-eoq reference/winqsb/DISCOUNT.IT_
```

Example output:

```text
Inventory Problem
unconstrainedEOQ: 31.622777
optimum.minimumQuantity: 80
optimum.discountPercent: 5
optimum.orderQuantity: 80
optimum.totalCost: 173775
```

## Newsboy

Supported input:

- Legacy WinQSB `ITS ... 2 2` newsboy files.
- Compressed `SZDD` fixtures such as `reference/winqsb/NEWSBOY.IT_`.
- Normal demand distribution with mean and standard deviation.
- Acquisition cost, selling price, opportunity shortage cost, salvage value,
  optional initial inventory, optional known order quantity, and optional
  desired service level.

The solver computes the critical ratio, optimal order quantity, service level,
expected sales, expected leftover inventory, expected shortage, and expected
profit.

Run:

```sh
qsb solve-newsboy reference/winqsb/NEWSBOY.IT_
```

Example output:

```text
Inventory Problem
distribution: Normal
criticalRatio: 0.800000
optimum.orderQuantity: 1084.162123
optimum.serviceLevel: 0.800000
optimum.expectedProfit: 9000.095199
```

## Lot Sizing

Supported input:

- Legacy WinQSB `ITS ... 3 ...` lot-sizing files.
- Compressed `SZDD` fixtures such as `reference/winqsb/LOTSIZE.IT_`.
- Period demand, setup cost, unit variable cost, unit holding cost, and unit
  backorder cost.

The solver uses finite-horizon dynamic programming with integer demand,
initial inventory of zero, and a balanced final inventory/backorder state. It
charges setup cost when production is positive, variable cost per produced
unit, and holding or backorder cost on each period's ending inventory.

Run:

```sh
qsb solve-lot-sizing reference/winqsb/LOTSIZE.IT_
```

Example output:

```text
Inventory Problem
timeUnit: month
totalCost: 907.500000
1: demand 20, produce 0, endingInventory -20, setup 0, variable 0, holding 0, backorder 20, cost 20
2: demand 30, produce 50, endingInventory 0, setup 40, variable 150, holding 0, backorder 0, cost 190
...
6: demand 35, produce 35, endingInventory 0, setup 30, variable 157.500000, holding 0, backorder 0, cost 187.500000
```
