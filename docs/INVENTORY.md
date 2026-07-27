# Inventory

The inventory module supports legacy WinQSB economic order quantity (EOQ),
all-units quantity discount EOQ, newsboy, finite-horizon lot sizing, and four
stochastic continuous/periodic review policies. All eight variants use the same `InventoryBackend` seam and normalized
`InventoryModelEnvelope` / `InventorySolutionDocument` JSON contracts.

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

Select the native educational or validation-only backend explicitly:

```sh
qsb solve-eoq reference/winqsb/EOQ.IT_ --backend native
qsb solve-eoq reference/winqsb/EOQ.IT_ --backend validate
qsb validate-eoq reference/winqsb/EOQ.IT_
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

## Stochastic Review Systems

The preserved modes 4 through 7 are supported:

- `CRSQ.IT_`: continuous review fixed-order-quantity `(Q,r)`;
- `CRSS.IT_`: continuous review order-up-to with supplied average order size;
- `PRRS.IT_`: periodic review with an optimized fixed review interval;
- `PRRSS.IT_`: periodic review with optional replenishment `(s,S)`.

The educational solver uses normal-demand loss functions, constant lead time,
continuous quantities, and expected shortage costs. It reports order quantity,
reorder/order-up-to levels, review interval where applicable, protection-period
demand, safety stock, service level, expected shortage, and annual costs.
These results are explicitly marked `approximate`.

```sh
qsb solve-stochastic-inventory reference/winqsb/CRSQ.IT_ --backend native
qsb validate-stochastic-inventory reference/winqsb/CRSQ.IT_
qsb export-inventory-json reference/winqsb/CRSQ.IT_ > stochastic.json
qsb solve-inventory-json stochastic.json --backend native
```

## Backend and Validation

`NativeEducationalInventoryBackend` preserves the existing fixture-scale
solvers and reports their character in `SolverRunMetadata`:

- EOQ/EPQ: closed-form economic order or production quantity.
- Quantity discount EOQ: exact enumeration of all-units discount tiers.
- Newsboy: closed-form normal-demand critical fractile.
- Lot sizing: exact finite-horizon dynamic programming within the current
  fixture-scale state bounds.
- Stochastic review: normal-loss approximations for continuous and periodic
  review policies with constant lead time.

`ValidateOnlyInventoryBackend` runs the same public validators used by the
solvers and does not solve. Diagnostics cover demand, rates, costs, discount
breaks, normal-demand assumptions, service levels, period labels, and period
costs. All legacy solve commands accept `--backend native|validate`, and each
variant also has an explicit validation command:

```sh
qsb validate-eoq reference/winqsb/EOQ.IT_
qsb validate-discount-eoq reference/winqsb/DISCOUNT.IT_
qsb validate-newsboy reference/winqsb/NEWSBOY.IT_
qsb validate-lot-sizing reference/winqsb/LOTSIZE.IT_
qsb validate-stochastic-inventory reference/winqsb/CRSQ.IT_
```

The `externalHighPerformance` kind remains an intentional extension point; no
external inventory backend is bundled yet.

## Normalized JSON

The generic inventory model envelope contains `kind` and `model`. Supported
kind values are `eoq`, `quantityDiscountEOQ`, `newsboy`, `lotSizing`, and
`stochasticReview`; the latter carries its policy as a second discriminator.

```sh
qsb export-inventory-json reference/winqsb/LOTSIZE.IT_ > inventory.json
qsb validate-inventory-json inventory.json
qsb solve-inventory-json inventory.json --backend native > inventory-solution.json
qsb solve-inventory-json inventory.json --backend validate
```

Native solution documents contain the model kind, title, time unit,
assumptions, backend algorithm/exactness metadata, and the typed solution.
Validation documents contain the kind, `validateOnly` backend, `isValid`, and
structured diagnostics. The same envelope works for all eight legacy fixtures,
so future CLI and GUI routing does not need to infer a type from arbitrary JSON
fields.

## macOS Workbench

`QSBMacApp` decodes the same `InventorySolutionDocument` emitted by
`InventoryBackend` and presents all five normalized solution kinds natively:

- EOQ cost components and supplied-quantity comparisons;
- quantity-discount candidates and the selected tier's cost breakdown;
- newsboy demand outcomes, service level, expected profit, and known-quantity
  comparison;
- lot-sizing demand, production, ending inventory/backlog, stacked period costs,
  and the complete decision table;
- stochastic policy levels, safety/service metrics, and expected ordering,
  review, holding, shortage, acquisition, relevant, and total costs.

The view adds no inventory formulas. It maps existing typed solution fields to
Charts and native tables, keeps backend exactness and assumptions visible, and
retains the normalized document through the Analysis/JSON selector.
