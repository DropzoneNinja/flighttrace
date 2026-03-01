// DataSmoother.swift
// Provides various smoothing algorithms for noisy GPS data

import Foundation
import Combine

/// Smoothing algorithm options
public enum SmoothingAlgorithm {
    case movingAverage(windowSize: Int)
    case exponentialMovingAverage(alpha: Double)
    case gaussianFilter(sigma: Double)
    case none
}

/// Utility for smoothing noisy telemetry data
public struct DataSmoother {

    // MARK: - Public API

    /// Smooth a series of values using the specified algorithm
    /// - Parameters:
    ///   - values: Array of values to smooth
    ///   - algorithm: Smoothing algorithm to use
    /// - Returns: Smoothed values
    public static func smooth(
        _ values: [Double],
        algorithm: SmoothingAlgorithm
    ) -> [Double] {
        guard !values.isEmpty else { return [] }

        switch algorithm {
        case .none:
            return values

        case .movingAverage(let windowSize):
            return movingAverage(values, windowSize: windowSize)

        case .exponentialMovingAverage(let alpha):
            return exponentialMovingAverage(values, alpha: alpha)

        case .gaussianFilter(let sigma):
            return gaussianFilter(values, sigma: sigma)
        }
    }

    // MARK: - Moving Average

    /// Apply simple moving average smoothing
    /// - Parameters:
    ///   - values: Values to smooth
    ///   - windowSize: Size of the moving window (must be odd)
    /// - Returns: Smoothed values
    private static func movingAverage(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize else { return values }

        var smoothed: [Double] = []
        let halfWindow = windowSize / 2

        for i in 0..<values.count {
            let startIndex = max(0, i - halfWindow)
            let endIndex = min(values.count - 1, i + halfWindow)
            let window = values[startIndex...endIndex]
            let average = window.reduce(0, +) / Double(window.count)
            smoothed.append(average)
        }

        return smoothed
    }

    // MARK: - Exponential Moving Average

    /// Apply exponential moving average (EMA) smoothing
    /// - Parameters:
    ///   - values: Values to smooth
    ///   - alpha: Smoothing factor (0 < alpha <= 1, higher = less smoothing)
    /// - Returns: Smoothed values
    private static func exponentialMovingAverage(
        _ values: [Double],
        alpha: Double
    ) -> [Double] {
        guard !values.isEmpty else { return [] }
        guard alpha > 0 && alpha <= 1 else { return values }

        var smoothed: [Double] = []
        var ema = values[0]
        smoothed.append(ema)

        for i in 1..<values.count {
            ema = alpha * values[i] + (1 - alpha) * ema
            smoothed.append(ema)
        }

        return smoothed
    }

    // MARK: - Gaussian Filter

    /// Apply Gaussian filter smoothing
    /// - Parameters:
    ///   - values: Values to smooth
    ///   - sigma: Standard deviation of Gaussian kernel
    /// - Returns: Smoothed values
    private static func gaussianFilter(_ values: [Double], sigma: Double) -> [Double] {
        guard values.count >= 3 else { return values }

        // Generate Gaussian kernel
        let kernelSize = Int(ceil(sigma * 3)) * 2 + 1
        let kernel = generateGaussianKernel(size: kernelSize, sigma: sigma)

        var smoothed: [Double] = []
        let halfKernel = kernelSize / 2

        for i in 0..<values.count {
            var weightedSum: Double = 0
            var weightTotal: Double = 0

            for j in 0..<kernelSize {
                let valueIndex = i - halfKernel + j
                if valueIndex >= 0 && valueIndex < values.count {
                    weightedSum += values[valueIndex] * kernel[j]
                    weightTotal += kernel[j]
                }
            }

            let smoothedValue = weightTotal > 0 ? weightedSum / weightTotal : values[i]
            smoothed.append(smoothedValue)
        }

        return smoothed
    }

    /// Generate a Gaussian kernel
    /// - Parameters:
    ///   - size: Size of the kernel (must be odd)
    ///   - sigma: Standard deviation
    /// - Returns: Gaussian kernel weights
    private static func generateGaussianKernel(size: Int, sigma: Double) -> [Double] {
        let center = size / 2
        var kernel: [Double] = []

        for i in 0..<size {
            let x = Double(i - center)
            let weight = exp(-(x * x) / (2 * sigma * sigma))
            kernel.append(weight)
        }

        // Normalize kernel
        let sum = kernel.reduce(0, +)
        return kernel.map { $0 / sum }
    }

    // MARK: - Interpolation

    /// Interpolate missing values using linear interpolation
    /// - Parameter values: Array of optional values
    /// - Returns: Array with interpolated values
    public static func interpolate(_ values: [Double?]) -> [Double] {
        guard !values.isEmpty else { return [] }

        var result: [Double] = []
        var lastValidIndex: Int?

        for i in 0..<values.count {
            if let value = values[i] {
                // Fill gaps between last valid value and current value
                if let lastIndex = lastValidIndex, lastIndex < i - 1 {
                    let lastValue = values[lastIndex]!
                    let steps = i - lastIndex
                    let delta = (value - lastValue) / Double(steps)

                    for j in 1..<steps {
                        let interpolated = lastValue + delta * Double(j)
                        result.append(interpolated)
                    }
                }

                result.append(value)
                lastValidIndex = i
            } else if lastValidIndex == nil {
                // No valid value yet, use 0 as placeholder
                result.append(0)
            }
        }

        // Fill any trailing nil values with last known value
        if let lastIndex = lastValidIndex, lastIndex < values.count - 1 {
            let lastValue = values[lastIndex]!
            for _ in (lastIndex + 1)..<values.count {
                if result.count < values.count {
                    result.append(lastValue)
                }
            }
        }

        return result
    }

    // MARK: - Outlier Detection

    /// Detect and remove outliers using z-score method
    /// - Parameters:
    ///   - values: Values to process
    ///   - threshold: Z-score threshold (typically 2-3)
    /// - Returns: Values with outliers replaced by interpolated values
    public static func removeOutliers(
        _ values: [Double],
        threshold: Double = 3.0
    ) -> [Double] {
        guard values.count >= 3 else { return values }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return values }

        var cleaned: [Double?] = []

        for value in values {
            let zScore = abs((value - mean) / stdDev)
            cleaned.append(zScore <= threshold ? value : nil)
        }

        return interpolate(cleaned)
    }
}
