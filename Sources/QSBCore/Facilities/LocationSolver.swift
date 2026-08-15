import Foundation

public enum FacilityLocationSolver {
    private struct WeightedPoint {
        let facility: FacilityLocationFacility
        let x: Double
        let y: Double
        let weight: Double
    }

    public static func solve(_ problem: FacilityLocationProblem) throws -> FacilityLocationSolution {
        let points = try validateAndBuildWeightedPoints(problem)
        let newFacility = problem.newFacilities[0]
        let coordinate = try optimalCoordinate(for: problem.distanceMeasure, points: points)
        let interactions = points.map { point in
            let distance = distance(
                from: coordinate,
                to: (x: point.x, y: point.y),
                measure: problem.distanceMeasure
            )
            return FacilityLocationInteraction(
                existingFacilityID: point.facility.id,
                existingFacilityName: point.facility.name,
                weight: point.weight,
                distance: distance,
                weightedDistance: point.weight * distance
            )
        }
        let weightedDistance = interactions.reduce(0) { $0 + $1.weightedDistance }
        let placement = FacilityLocationPlacement(
            facilityID: newFacility.id,
            facilityName: newFacility.name,
            x: coordinate.x,
            y: coordinate.y,
            weightedDistance: weightedDistance,
            interactions: interactions
        )

        return FacilityLocationSolution(
            distanceMeasure: problem.distanceMeasure,
            objectiveValue: weightedDistance,
            placements: [placement]
        )
    }

    private static func validateAndBuildWeightedPoints(_ problem: FacilityLocationProblem) throws -> [WeightedPoint] {
        try FacilityLocationValidator.validate(problem)

        guard problem.objective == "MIN" else {
            throw FacilitiesModelError.invalidModel("facility location currently supports minimization only")
        }
        guard problem.newFacilities.count == 1 else {
            throw FacilitiesModelError.invalidModel("facility location currently supports exactly one new facility")
        }
        guard !problem.existingFacilities.isEmpty else {
            throw FacilitiesModelError.invalidModel("facility location requires existing facilities")
        }

        let totalFacilityCount = problem.facilities.count
        for facility in problem.facilities {
            guard facility.interactionCosts.count == totalFacilityCount else {
                throw FacilitiesModelError.invalidModel("facility location interaction rows must match facility count")
            }
        }

        guard let newIndex = problem.facilities.firstIndex(where: \.isNew) else {
            throw FacilitiesModelError.invalidModel("facility location requires a new facility")
        }

        var points: [WeightedPoint] = []
        for existingIndex in problem.facilities.indices where !problem.facilities[existingIndex].isNew {
            let existing = problem.facilities[existingIndex]
            guard let x = existing.x, let y = existing.y else {
                throw FacilitiesModelError.invalidModel("existing facilities require coordinates")
            }
            let forwardWeight = problem.facilities[newIndex].interactionCosts[existingIndex] ?? 0
            let reverseWeight = problem.facilities[existingIndex].interactionCosts[newIndex] ?? 0
            let weight = forwardWeight + reverseWeight
            guard weight >= 0 else {
                throw FacilitiesModelError.invalidModel("facility location interaction weights must be nonnegative")
            }
            if weight > 0 {
                points.append(WeightedPoint(facility: existing, x: x, y: y, weight: weight))
            }
        }

        guard !points.isEmpty else {
            throw FacilitiesModelError.invalidModel("facility location requires at least one positive interaction")
        }
        return points
    }

    private static func optimalCoordinate(
        for measure: FacilityLocationDistanceMeasure,
        points: [WeightedPoint]
    ) throws -> (x: Double, y: Double) {
        switch measure {
        case .rectilinear:
            return (
                x: weightedMedian(points.map { (coordinate: $0.x, weight: $0.weight) }),
                y: weightedMedian(points.map { (coordinate: $0.y, weight: $0.weight) })
            )
        case .squaredEuclidean:
            let totalWeight = points.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else {
                throw FacilitiesModelError.invalidModel("facility location requires positive total weight")
            }
            return (
                x: points.reduce(0) { $0 + $1.weight * $1.x } / totalWeight,
                y: points.reduce(0) { $0 + $1.weight * $1.y } / totalWeight
            )
        case .euclidean:
            return try weiszfeldCoordinate(points)
        }
    }

    private static func weightedMedian(_ values: [(coordinate: Double, weight: Double)]) -> Double {
        let sorted = values.sorted { $0.coordinate < $1.coordinate }
        let halfWeight = sorted.reduce(0) { $0 + $1.weight } / 2.0
        var cumulativeWeight = 0.0
        for value in sorted {
            cumulativeWeight += value.weight
            if cumulativeWeight >= halfWeight {
                return value.coordinate
            }
        }
        return sorted.last?.coordinate ?? 0
    }

    private static func weiszfeldCoordinate(_ points: [WeightedPoint]) throws -> (x: Double, y: Double) {
        var coordinate = try optimalCoordinate(for: .squaredEuclidean, points: points)
        for _ in 0..<1_000 {
            var numeratorX = 0.0
            var numeratorY = 0.0
            var denominator = 0.0
            for point in points {
                let euclideanDistance = hypot(coordinate.x - point.x, coordinate.y - point.y)
                if euclideanDistance < 1e-10 {
                    return (x: point.x, y: point.y)
                }
                let scaledWeight = point.weight / euclideanDistance
                numeratorX += scaledWeight * point.x
                numeratorY += scaledWeight * point.y
                denominator += scaledWeight
            }
            guard denominator > 0 else {
                throw FacilitiesModelError.invalidModel("facility location euclidean iteration failed")
            }
            let next = (x: numeratorX / denominator, y: numeratorY / denominator)
            if hypot(next.x - coordinate.x, next.y - coordinate.y) < 1e-9 {
                return next
            }
            coordinate = next
        }
        return coordinate
    }

    private static func distance(
        from origin: (x: Double, y: Double),
        to destination: (x: Double, y: Double),
        measure: FacilityLocationDistanceMeasure
    ) -> Double {
        let dx = origin.x - destination.x
        let dy = origin.y - destination.y
        switch measure {
        case .rectilinear:
            return abs(dx) + abs(dy)
        case .squaredEuclidean:
            return dx * dx + dy * dy
        case .euclidean:
            return hypot(dx, dy)
        }
    }
}


