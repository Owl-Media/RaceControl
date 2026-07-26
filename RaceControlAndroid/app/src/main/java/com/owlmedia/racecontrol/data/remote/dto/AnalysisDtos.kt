package com.owlmedia.racecontrol.data.remote.dto

import com.owlmedia.racecontrol.core.design.teamColor
import com.owlmedia.racecontrol.core.util.pointsLabel
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/* -------------------------------------------------------- lap-time evolution */

@Serializable
data class LapTimesResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val eventName: String? = null,
    val totalLaps: Int = 0,
    val drivers: List<LapTimeDriverDto> = emptyList(),
)

@Serializable
data class LapTimeDriverDto(
    val code: String = "",
    val driverId: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val laps: List<LapTimePointDto> = emptyList(),
)

@Serializable
data class LapTimePointDto(
    val lap: Int = 0,
    val timeMs: Int = 0,
    val compound: String? = null,
) {
    val seconds: Double get() = timeMs / 1000.0
}

/* ------------------------------------------------------------- tyre strategy */

@Serializable
data class StrategyResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val eventName: String? = null,
    val totalLaps: Int = 0,
    val drivers: List<StrategyDriverDto> = emptyList(),
)

@Serializable
data class StrategyDriverDto(
    val code: String = "",
    val driverId: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val pitStops: Int = 0,
    val stints: List<StintDto> = emptyList(),
)

@Serializable
data class StintDto(
    val stint: Int = 0,
    val compound: String? = null,
    val startLap: Int = 0,
    val endLap: Int = 0,
    val laps: Int = 0,
)

/* ------------------------------------------------------------------- weather */

@Serializable
data class WeatherResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val session: String = "",
    val eventName: String? = null,
    val available: Boolean = false,
    val airTemp: Double? = null,
    val trackTemp: Double? = null,
    val humidity: Double? = null,
    val pressure: Double? = null,
    val windSpeed: Double? = null,
    val rainfall: Boolean? = null,
    val airTempMax: Double? = null,
    val trackTempMax: Double? = null,
)

/* ----------------------------------------------------------------- telemetry */

@Serializable
data class TelemetryResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val available: Boolean = false,
    val eventName: String? = null,
    val trace: TelemetryTraceDto? = null,
)

@Serializable
data class TelemetryCompareResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val eventName: String? = null,
    val available: Boolean = false,
    val traces: List<TelemetryTraceDto> = emptyList(),
)

@Serializable
data class TelemetryTraceDto(
    val code: String = "",
    val driverName: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val lapNumber: Int? = null,
    val lapTime: String? = null,
    val lapTimeMs: Int? = null,
    val compound: String? = null,
    val distance: List<Double> = emptyList(),
    val time: List<Double>? = null,
    val speed: List<Double> = emptyList(),
    val throttle: List<Double> = emptyList(),
    val brake: List<Int> = emptyList(),
    val gear: List<Int> = emptyList(),
    val rpm: List<Int> = emptyList(),
    val drs: List<Int> = emptyList(),
    val x: List<Double> = emptyList(),
    val y: List<Double> = emptyList(),
) {
    /**
     * Nearest sample index for a distance along the lap.
     *
     * The telemetry replay needs this on every frame, and the distance array is
     * sorted, so binary search keeps it O(log n) rather than scanning ~5,000
     * samples 60 times a second.
     */
    fun indexAtDistance(target: Double): Int {
        if (distance.isEmpty()) return 0
        var low = 0
        var high = distance.lastIndex
        while (low < high) {
            val mid = (low + high) / 2
            if (distance[mid] < target) low = mid + 1 else high = mid
        }
        // Prefer whichever neighbour is genuinely closer.
        if (low > 0 && kotlin.math.abs(distance[low - 1] - target) <
            kotlin.math.abs(distance[low] - target)
        ) {
            return low - 1
        }
        return low
    }

    fun speedAt(distanceAlongLap: Double): Double? =
        speed.getOrNull(indexAtDistance(distanceAlongLap))

    fun gearAt(distanceAlongLap: Double): Int? =
        gear.getOrNull(indexAtDistance(distanceAlongLap))

    fun throttleAt(distanceAlongLap: Double): Double? =
        throttle.getOrNull(indexAtDistance(distanceAlongLap))

    fun brakeAt(distanceAlongLap: Double): Boolean? =
        brake.getOrNull(indexAtDistance(distanceAlongLap))?.let { it > 0 }

    val maxDistance: Double get() = distance.lastOrNull() ?: 0.0
}

/* ------------------------------------------------------- race driver pickers */

@Serializable
data class RaceDriverDto(
    val code: String? = null,
    val driverId: String? = null,
    val fullName: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val number: String? = null,
) {
    val id: String get() = code ?: driverId ?: fullName ?: "unknown"
}

/* --------------------------------------------------------------- retirements */

@Serializable
data class RetirementsResponseDto(
    val year: Int = 0,
    val round: Int = 0,
    val eventName: String? = null,
    val retirements: List<RetirementDto> = emptyList(),
)

@Serializable
data class RetirementDto(
    val driver: String? = null,
    val fullName: String? = null,
    val driverId: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val status: String? = null,
    val classifiedPosition: String? = null,
) {
    val id: String get() = driver ?: driverId ?: "unknown"

    /** Buckets the free-text status into the four causes the iOS app shows. */
    val cause: RetirementCause
        get() {
            val s = status.orEmpty().lowercase()
            return when {
                s.contains("disqualif") -> RetirementCause.DISQUALIFIED
                s.contains("accident") || s.contains("collision") ||
                    s.contains("spun") || s.contains("damage") -> RetirementCause.ACCIDENT
                s.contains("engine") || s.contains("gearbox") || s.contains("hydraulic") ||
                    s.contains("brake") || s.contains("suspension") || s.contains("power") ||
                    s.contains("transmission") || s.contains("electrical") ||
                    s.contains("mechanical") || s.contains("overheating") ||
                    s.contains("wheel") || s.contains("puncture") ||
                    s.contains("fuel") || s.contains("oil") ||
                    s.contains("water") || s.contains("clutch") ||
                    s.contains("driveshaft") || s.contains("exhaust") ||
                    s.contains("turbo") || s.contains("battery") ||
                    s.contains("radiator") || s.contains("throttle") ||
                    s.contains("differential") || s.contains("steering") ||
                    s.contains("tyre") || s.contains("retired") -> RetirementCause.MECHANICAL
                else -> RetirementCause.OTHER
            }
        }
}

enum class RetirementCause { MECHANICAL, ACCIDENT, DISQUALIFIED, OTHER }

/* --------------------------------------------------------------- reliability */

@Serializable
data class ReliabilityResponseDto(
    val year: Int = 0,
    val races: Int = 0,
    val drivers: List<ReliabilityDriverDto> = emptyList(),
    val teams: List<ReliabilityTeamDto> = emptyList(),
)

@Serializable
data class ReliabilityDriverDto(
    val driverId: String = "",
    val name: String = "",
    val teamId: String? = null,
    val finished: Int = 0,
    val mechanical: Int = 0,
    val accident: Int = 0,
    val disqualified: Int = 0,
    val other: Int = 0,
    val dnf: Int = 0,
    val starts: Int = 0,
    val finishRate: Double = 0.0,
)

@Serializable
data class ReliabilityTeamDto(
    val teamId: String = "",
    val teamName: String? = null,
    val finished: Int = 0,
    val mechanical: Int = 0,
    val accident: Int = 0,
    val disqualified: Int = 0,
    val other: Int = 0,
    val dnf: Int = 0,
    val starts: Int = 0,
    val finishRate: Double = 0.0,
)

/* -------------------------------------------------------- standings evolution */

@Serializable
data class StandingsEvolutionDto(
    val year: Int = 0,
    val rounds: List<Int> = emptyList(),
    val drivers: List<EvolutionDriverDto> = emptyList(),
)

@Serializable
data class EvolutionDriverDto(
    val driverId: String = "",
    val name: String = "",
    val code: String? = null,
    val teamName: String? = null,
    val teamColor: String? = null,
    val points: Double = 0.0,
    val series: List<EvolutionPointDto> = emptyList(),
)

@Serializable
data class EvolutionPointDto(
    val round: Int = 0,
    val points: Double = 0.0,
)

/* ------------------------------------------------------------- head-to-head */

@Serializable
data class CompareResponseDto(
    val year: Int = 0,
    val drivers: List<CompareDriverDto> = emptyList(),
)

@Serializable
data class CompareDriverDto(
    val driverId: String = "",
    val name: String = "",
    val teamName: String? = null,
    val points: Double = 0.0,
    val wins: Int = 0,
    val podiums: Int = 0,
    val poles: Int = 0,
    val bestFinish: Int? = null,
    val dnf: Int = 0,
    // The backend uses snake-ish keys for just these two fields.
    @SerialName("raceWins_h2h") val raceWinsH2h: Int = 0,
    @SerialName("qualWins_h2h") val qualWinsH2h: Int = 0,
) {
    val pointsLabel: String
        get() = if (points % 1.0 == 0.0) points.toInt().toString() else points.toString()
}

/** Error body the FastAPI backend returns alongside a non-2xx status. */
@Serializable
data class ApiErrorBodyDto(val detail: String? = null)
