package com.owlmedia.racecontrol.feature.analysis

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.PauseCircleFilled
import androidx.compose.material.icons.filled.PlayCircleFilled
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.owlmedia.racecontrol.R
import com.owlmedia.racecontrol.core.design.Dimens
import com.owlmedia.racecontrol.core.design.RcTheme
import com.owlmedia.racecontrol.core.design.legibleOnSurface
import com.owlmedia.racecontrol.core.design.tabular
import com.owlmedia.racecontrol.core.design.teamColor
import com.owlmedia.racecontrol.core.ui.ChartDomain
import com.owlmedia.racecontrol.core.ui.ChartPoint
import com.owlmedia.racecontrol.core.ui.ChartSeries
import com.owlmedia.racecontrol.core.ui.EmptyState
import com.owlmedia.racecontrol.core.ui.ErrorState
import com.owlmedia.racecontrol.core.ui.LoadableContent
import com.owlmedia.racecontrol.core.ui.LoadingIndicator
import com.owlmedia.racecontrol.core.ui.RcCard
import com.owlmedia.racecontrol.core.ui.RcDetailScaffold
import com.owlmedia.racecontrol.core.ui.RcLineChart
import com.owlmedia.racecontrol.core.ui.SectionHeader
import com.owlmedia.racecontrol.core.ui.StatCell
import com.owlmedia.racecontrol.core.util.Downsample
import com.owlmedia.racecontrol.data.remote.dto.TelemetryTraceDto
import kotlin.math.roundToInt

@Composable
fun TelemetryScreen(
    year: Int,
    round: Int,
    title: String,
    onBack: () -> Unit,
    viewModel: TelemetryViewModel = hiltViewModel(),
) {
    val driversState by viewModel.drivers.collectAsStateWithLifecycle()
    val selected by viewModel.selected.collectAsStateWithLifecycle()
    val traces by viewModel.traces.collectAsStateWithLifecycle()
    val loadingTraces by viewModel.loadingTraces.collectAsStateWithLifecycle()
    val traceError by viewModel.traceError.collectAsStateWithLifecycle()
    val playhead by viewModel.playhead.collectAsStateWithLifecycle()
    val isPlaying by viewModel.isPlaying.collectAsStateWithLifecycle()

    LaunchedEffect(year, round) { viewModel.loadDrivers(year, round) }
    DisposableEffect(Unit) { onDispose { viewModel.stopReplay() } }

    RcDetailScaffold(
        title = stringResource(R.string.analysis_telemetry),
        onBack = onBack,
    ) { modifier ->
        LoadableContent(
            state = driversState,
            onRetry = { viewModel.loadDrivers(year, round) },
            modifier = modifier,
            loadingLabel = stringResource(R.string.loading_drivers),
        ) { drivers ->
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(Dimens.MD),
                verticalArrangement = Arrangement.spacedBy(Dimens.MD),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.SM),
                ) {
                    drivers.forEach { driver ->
                        val code = driver.code ?: return@forEach
                        val accent = teamColor(driver.teamColor).legibleOnSurface()
                        val isSelected = code in selected
                        FilterChip(
                            selected = isSelected,
                            onClick = { viewModel.toggleDriver(code) },
                            // Chips that would exceed the three-driver limit are
                            // disabled rather than silently doing nothing.
                            enabled = isSelected ||
                                selected.size < TelemetryViewModel.MAX_DRIVERS,
                            label = { Text(code) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = accent.copy(alpha = 0.3f),
                                selectedLabelColor = RcTheme.colors.textPrimary,
                            ),
                        )
                    }
                }

                if (selected.size >= TelemetryViewModel.MAX_DRIVERS) {
                    Text(
                        text = stringResource(R.string.telemetry_max_drivers),
                        style = MaterialTheme.typography.labelSmall,
                        color = RcTheme.colors.textTertiary,
                    )
                }

                when {
                    loadingTraces -> LoadingIndicator(
                        modifier = Modifier.height(180.dp),
                        label = stringResource(R.string.loading_telemetry),
                    )

                    traceError != null -> ErrorState(
                        message = traceError.orEmpty(),
                        onRetry = { selected.firstOrNull()?.let(viewModel::toggleDriver) },
                        modifier = Modifier.height(220.dp),
                    )

                    traces.isEmpty() -> EmptyState(
                        icon = Icons.Filled.MonitorHeart,
                        title = stringResource(R.string.telemetry_pick_title),
                        message = stringResource(R.string.telemetry_pick_message),
                        modifier = Modifier.height(220.dp),
                    )

                    else -> TelemetryContent(
                        traces = traces,
                        playhead = playhead,
                        isPlaying = isPlaying,
                        onPlayhead = viewModel::setPlayhead,
                        onToggleReplay = viewModel::toggleReplay,
                    )
                }
            }
        }
    }
}

@Composable
private fun TelemetryContent(
    traces: List<TelemetryTraceDto>,
    playhead: Double,
    isPlaying: Boolean,
    onPlayhead: (Double) -> Unit,
    onToggleReplay: () -> Unit,
) {
    val maxDistance = remember(traces) { traces.maxOfOrNull { it.maxDistance } ?: 1.0 }

    // Downsampled once per trace set, not on every recomposition. A raw trace
    // is several thousand points per channel and would otherwise be re-walked
    // 60 times a second while the playhead sweeps.
    val speedSeries = remember(traces) { traces.toSeries { it.speed } }
    val throttleSeries = remember(traces) { traces.toSeries { it.throttle } }
    val gearSeries = remember(traces) { traces.toSeries { trace -> trace.gear.map { it.toDouble() } } }

    Column(verticalArrangement = Arrangement.spacedBy(Dimens.MD)) {
        RcCard {
            SectionHeader("LAP")
            traces.forEach { trace ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = trace.code,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = teamColor(trace.teamColor).legibleOnSurface(),
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = trace.lapTime.orEmpty(),
                        style = MaterialTheme.typography.bodyMedium.tabular(),
                        color = RcTheme.colors.textPrimary,
                    )
                }
            }
        }

        RcCard {
            MiniTrackMap(traces = traces, playhead = playhead)
        }

        RcCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onToggleReplay, modifier = Modifier.size(Dimens.MinTouch)) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Filled.PauseCircleFilled
                        else Icons.Filled.PlayCircleFilled,
                        contentDescription = stringResource(
                            if (isPlaying) R.string.replay_pause else R.string.replay_play
                        ),
                        tint = RcTheme.colors.racingRed,
                    )
                }
                Slider(
                    value = playhead.toFloat(),
                    onValueChange = { onPlayhead(it.toDouble()) },
                    valueRange = 0f..maxDistance.toFloat(),
                    modifier = Modifier
                        .weight(1f)
                        .semantics {
                            contentDescription =
                                "Lap position, ${playhead.roundToInt()} of " +
                                    "${maxDistance.roundToInt()} metres"
                        },
                )
            }

            Row(Modifier.fillMaxWidth()) {
                traces.forEach { trace ->
                    val accent = teamColor(trace.teamColor).legibleOnSurface()
                    StatCell(
                        value = trace.speedAt(playhead)?.roundToInt()?.toString() ?: "–",
                        label = "${trace.code} ${stringResource(R.string.unit_kmh)}",
                        accent = accent,
                        modifier = Modifier.weight(1f),
                    )
                    StatCell(
                        value = trace.gearAt(playhead)?.toString() ?: "–",
                        label = "${trace.code} ${stringResource(R.string.telemetry_gear)}",
                        accent = accent,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }

        TelemetryChartCard(
            title = stringResource(R.string.telemetry_speed),
            unit = stringResource(R.string.unit_kmh),
            series = speedSeries,
            playhead = playhead,
            onPlayhead = onPlayhead,
            height = 190.dp,
            // Speed can't go negative; the default padding otherwise can push
            // a low-min-speed lap's axis just under zero.
            minClamp = 0.0,
        )
        TelemetryChartCard(
            title = stringResource(R.string.telemetry_throttle),
            unit = stringResource(R.string.unit_percent),
            series = throttleSeries,
            playhead = playhead,
            onPlayhead = onPlayhead,
            height = 120.dp,
            // Throttle is a 0-100% signal; unclamped padding was drawing an
            // axis from -6 to 110, which is meaningless for a percentage.
            minClamp = 0.0,
            maxClamp = 100.0,
        )
        TelemetryChartCard(
            title = stringResource(R.string.telemetry_gear),
            unit = "",
            series = gearSeries,
            playhead = playhead,
            onPlayhead = onPlayhead,
            height = 120.dp,
            // Gear numbers can't go below neutral/zero.
            minClamp = 0.0,
        )

        if (traces.size == 2) {
            TelemetryComparison(traces[0], traces[1])
        }
    }
}

@Composable
private fun TelemetryChartCard(
    title: String,
    unit: String,
    series: List<ChartSeries>,
    playhead: Double,
    onPlayhead: (Double) -> Unit,
    height: androidx.compose.ui.unit.Dp,
    minClamp: Double? = null,
    maxClamp: Double? = null,
) {
    val domain = remember(series, minClamp, maxClamp) {
        val raw = ChartDomain.cover(series)
        raw.copy(
            minY = minClamp?.let { floor -> maxOf(floor, raw.minY) } ?: raw.minY,
            maxY = maxClamp?.let { ceiling -> minOf(ceiling, raw.maxY) } ?: raw.maxY,
        )
    }
    val axisLabels = remember(domain) {
        (0..4).map { index ->
            val value = domain.minY + domain.spanY * (index / 4.0)
            value.roundToInt().toString()
        }
    }

    RcCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            SectionHeader(title.uppercase())
            if (unit.isNotEmpty()) {
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = RcTheme.colors.textTertiary,
                )
            }
        }
        RcLineChart(
            series = series,
            domain = domain,
            yAxisLabels = axisLabels,
            height = height,
            playheadX = playhead,
            onPlayheadChange = onPlayhead,
        )
    }
}

/**
 * The lap drawn from the trace's own x/y channels, with a dot per driver at the
 * playhead — so you can see *where* on the circuit a speed difference happens,
 * not just that it does.
 */
@Composable
private fun MiniTrackMap(traces: List<TelemetryTraceDto>, playhead: Double) {
    val reference = traces.firstOrNull { it.x.isNotEmpty() } ?: return

    Canvas(
        Modifier
            .fillMaxWidth()
            .height(200.dp),
    ) {
        val minX = reference.x.min()
        val maxX = reference.x.max()
        val minY = reference.y.min()
        val maxY = reference.y.max()
        val spanX = (maxX - minX).takeIf { it > 0 } ?: 1.0
        val spanY = (maxY - minY).takeIf { it > 0 } ?: 1.0
        val padding = 16f
        val availableWidth = size.width - padding * 2
        val availableHeight = size.height - padding * 2
        val fit = minOf(availableWidth / spanX, availableHeight / spanY).toFloat()

        // Centre the slack the aspect-ratio difference leaves over, so the lap
        // sits in the middle of the card rather than hugging the top-left.
        val originX = padding + (availableWidth - (spanX * fit).toFloat()) / 2f
        val originY = padding + (availableHeight - (spanY * fit).toFloat()) / 2f

        fun project(x: Double, y: Double) = Offset(
            originX + ((x - minX) * fit).toFloat(),
            // Track Y grows "up"; canvas Y grows down.
            originY + ((maxY - y) * fit).toFloat(),
        )

        val path = Path()
        reference.x.indices.forEach { index ->
            val p = project(reference.x[index], reference.y[index])
            if (index == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
        }
        drawPath(
            path = path,
            color = Color.White.copy(alpha = 0.25f),
            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
        )

        traces.forEach { trace ->
            if (trace.x.isEmpty()) return@forEach
            val index = trace.indexAtDistance(playhead)
            val x = trace.x.getOrNull(index) ?: return@forEach
            val y = trace.y.getOrNull(index) ?: return@forEach
            drawCircle(
                color = teamColor(trace.teamColor),
                radius = 6.dp.toPx(),
                center = project(x, y),
            )
        }
    }
}

/** Zips distance with a channel, downsampled for the chart. */
private fun List<TelemetryTraceDto>.toSeries(
    channel: (TelemetryTraceDto) -> List<Double>,
): List<ChartSeries> = mapNotNull { trace ->
    val values = channel(trace)
    if (values.isEmpty() || trace.distance.isEmpty()) return@mapNotNull null
    val (xs, ys) = Downsample.cap(trace.distance, values, max = 800)
    ChartSeries(
        id = trace.code,
        color = teamColor(trace.teamColor).legibleOnSurface(),
        points = xs.indices.map { ChartPoint(xs[it], ys[it]) },
    )
}
