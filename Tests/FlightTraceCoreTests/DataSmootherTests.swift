// DataSmootherTests.swift
// Unit tests for data smoothing algorithms

import XCTest
@testable import FlightTraceCore

final class DataSmootherTests: XCTestCase {

    // MARK: - Moving Average Tests

    func testMovingAverage() {
        let values = [1.0, 5.0, 3.0, 7.0, 9.0, 2.0, 4.0]
        let smoothed = DataSmoother.smooth(values, algorithm: .movingAverage(windowSize: 3))

        XCTAssertEqual(smoothed.count, values.count)

        // First value should be average of first 2 points (window can't extend before start)
        XCTAssertGreaterThan(smoothed[0], 1.0)
        XCTAssertLessThan(smoothed[0], 5.0)

        // Middle values should be smoother than original
        XCTAssertNotEqual(smoothed[3], values[3])
    }

    func testMovingAverageWindowSize1() {
        let values = [1.0, 2.0, 3.0]
        let smoothed = DataSmoother.smooth(values, algorithm: .movingAverage(windowSize: 1))

        // Window size 1 should return original values
        XCTAssertEqual(smoothed, values)
    }

    // MARK: - Exponential Moving Average Tests

    func testExponentialMovingAverage() {
        let values = [10.0, 20.0, 15.0, 25.0, 30.0]
        let smoothed = DataSmoother.smooth(
            values,
            algorithm: .exponentialMovingAverage(alpha: 0.3)
        )

        XCTAssertEqual(smoothed.count, values.count)

        // First value should be unchanged
        XCTAssertEqual(smoothed[0], values[0])

        // Subsequent values should be smoothed
        XCTAssertNotEqual(smoothed[1], values[1])
    }

    func testExponentialMovingAverageHighAlpha() {
        let values = [10.0, 20.0, 30.0]
        let smoothed = DataSmoother.smooth(
            values,
            algorithm: .exponentialMovingAverage(alpha: 1.0)
        )

        // Alpha = 1.0 should return nearly original values
        for i in 0..<values.count {
            XCTAssertEqual(smoothed[i], values[i], accuracy: 0.1)
        }
    }

    // MARK: - Gaussian Filter Tests

    func testGaussianFilter() {
        let values = [1.0, 5.0, 3.0, 7.0, 9.0, 2.0, 4.0]
        let smoothed = DataSmoother.smooth(values, algorithm: .gaussianFilter(sigma: 1.0))

        XCTAssertEqual(smoothed.count, values.count)

        // Values should be smoothed
        for i in 1..<(values.count - 1) {
            // Smoothed values should be influenced by neighbors
            XCTAssertNotEqual(smoothed[i], values[i])
        }
    }

    // MARK: - Interpolation Tests

    func testInterpolate() {
        let values: [Double?] = [1.0, nil, nil, 4.0, nil, 6.0]
        let interpolated = DataSmoother.interpolate(values)

        XCTAssertEqual(interpolated.count, values.count)
        XCTAssertEqual(interpolated[0], 1.0)
        XCTAssertEqual(interpolated[3], 4.0)

        // Check that gaps are filled
        XCTAssertGreaterThan(interpolated[1], 1.0)
        XCTAssertLessThan(interpolated[1], 4.0)
        XCTAssertGreaterThan(interpolated[2], 1.0)
        XCTAssertLessThan(interpolated[2], 4.0)
    }

    func testInterpolateNoGaps() {
        let values: [Double?] = [1.0, 2.0, 3.0, 4.0]
        let interpolated = DataSmoother.interpolate(values)

        XCTAssertEqual(interpolated.count, values.count)
        XCTAssertEqual(interpolated[0], 1.0)
        XCTAssertEqual(interpolated[1], 2.0)
        XCTAssertEqual(interpolated[2], 3.0)
        XCTAssertEqual(interpolated[3], 4.0)
    }

    func testInterpolateLeadingNils() {
        let values: [Double?] = [nil, nil, 3.0, 4.0]
        let interpolated = DataSmoother.interpolate(values)

        XCTAssertEqual(interpolated.count, values.count)
        // Leading nils should be filled with 0 or first valid value
        XCTAssertEqual(interpolated[2], 3.0)
        XCTAssertEqual(interpolated[3], 4.0)
    }

    // MARK: - Outlier Detection Tests

    func testRemoveOutliers() {
        let values = [10.0, 11.0, 10.5, 100.0, 10.2, 11.5, 10.8]
        let cleaned = DataSmoother.removeOutliers(values, threshold: 2.0)

        XCTAssertEqual(cleaned.count, values.count)

        // Outlier (100.0) should be replaced with interpolated value
        XCTAssertNotEqual(cleaned[3], 100.0)
        XCTAssertLessThan(cleaned[3], 20.0) // Should be much closer to surrounding values
    }

    func testRemoveOutliersNoOutliers() {
        let values = [10.0, 11.0, 10.5, 11.2, 10.8, 11.5]
        let cleaned = DataSmoother.removeOutliers(values)

        // No outliers, so values should be mostly unchanged
        for i in 0..<values.count {
            XCTAssertEqual(cleaned[i], values[i], accuracy: 0.5)
        }
    }

    // MARK: - Edge Case Tests

    func testEmptyArray() {
        let values: [Double] = []
        let smoothed = DataSmoother.smooth(values, algorithm: .movingAverage(windowSize: 3))

        XCTAssertTrue(smoothed.isEmpty)
    }

    func testSingleValue() {
        let values = [42.0]
        let smoothed = DataSmoother.smooth(values, algorithm: .movingAverage(windowSize: 3))

        XCTAssertEqual(smoothed.count, 1)
        XCTAssertEqual(smoothed[0], 42.0)
    }

    func testNoSmoothing() {
        let values = [1.0, 2.0, 3.0, 4.0]
        let unsmoothed = DataSmoother.smooth(values, algorithm: .none)

        XCTAssertEqual(unsmoothed, values)
    }
}
