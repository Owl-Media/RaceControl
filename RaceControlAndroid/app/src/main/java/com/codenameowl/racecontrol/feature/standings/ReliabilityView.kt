package com.codenameowl.racecontrol.feature.standings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.codenameowl.racecontrol.R
import com.codenameowl.racecontrol.core.design.Dimens
import com.codenameowl.racecontrol.core.design.RcShapes
import com.codenameowl.racecontrol.core.design.RcTheme
import com.codenameowl.racecontrol.core.design.tabular
import com.codenameowl.racecontrol.core.ui.BarSegment
import com.codenameowl.racecontrol.core.ui.EmptyState
import com.codenameowl.racecontrol.core.ui.LoadableContent
import com.codenameowl.racecontrol.core.ui.SectionHeader
import com.codenameowl.racecontrol.core.ui.StackedBar
import com.codenameowl.racecontrol.feature.AppState

/**
 * Season finish rate with a DNF breakdown by cause, for drivers and teams.
 */
@Composable
fun ReliabilityView(viewModel: StandingsViewModel, appState: AppState) {
    val state by viewModel.reliability.collectAsStateWithLifecycle()

    LoadableContent(
        state = state,
        onRetry = { viewModel.load(appState.selectedYear, StandingsMode.RELIABILITY, force = true) },
    ) { data ->
        if (data.drivers.isEmpty() && data.teams.isEmpty()) {
            EmptyState(
                icon = Icons.Filled.Build,
                title = stringResource(R.string.no_standings_title),
                message = stringResource(
                    R.string.no_standings_message,
                    appState.selectedYear.toString(),
                ),
            )
            return@LoadableContent
        }

        LazyColumn(
            contentPadding = PaddingValues(Dimens.MD),
            verticalArrangement = Arrangement.spacedBy(Dimens.SM),
        ) {
            item(key = "legend") { CauseLegend() }

            item(key = "drivers-header") {
                SectionHeader(stringResource(R.string.standings_drivers))
            }
            items(
                items = data.drivers.sortedByDescending { it.finishRate },
                key = { "driver-${it.driverId}" },
                contentType = { "reliability" },
            ) { driver ->
                ReliabilityRow(
                    name = driver.name,
                    finished = driver.finished,
                    mechanical = driver.mechanical,
                    accident = driver.accident,
                    disqualified = driver.disqualified,
                    other = driver.other,
                    starts = driver.starts,
                    finishRate = driver.finishRate,
                )
            }

            item(key = "teams-header") {
                SectionHeader(stringResource(R.string.standings_teams))
            }
            items(
                items = data.teams.sortedByDescending { it.finishRate },
                key = { "team-${it.teamId}" },
                contentType = { "reliability" },
            ) { team ->
                ReliabilityRow(
                    name = team.teamName ?: team.teamId,
                    finished = team.finished,
                    mechanical = team.mechanical,
                    accident = team.accident,
                    disqualified = team.disqualified,
                    other = team.other,
                    starts = team.starts,
                    finishRate = team.finishRate,
                )
            }
        }
    }
}

@Composable
private fun CauseLegend() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = Dimens.SM),
        horizontalArrangement = Arrangement.spacedBy(Dimens.MD),
    ) {
        LegendDot(RcTheme.colors.positive, stringResource(R.string.cause_finished))
        LegendDot(RcTheme.colors.warning, stringResource(R.string.cause_mechanical))
        LegendDot(RcTheme.colors.negative, stringResource(R.string.cause_accident))
        LegendDot(RcTheme.colors.textTertiary, stringResource(R.string.cause_other))
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color)
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = RcTheme.colors.textSecondary,
        )
    }
}

@Composable
private fun ReliabilityRow(
    name: String,
    finished: Int,
    mechanical: Int,
    accident: Int,
    disqualified: Int,
    other: Int,
    starts: Int,
    finishRate: Double,
) {
    val ratePercent = (finishRate * 100).toInt()
    val segments = listOf(
        BarSegment(finished.toFloat(), RcTheme.colors.positive),
        BarSegment(mechanical.toFloat(), RcTheme.colors.warning),
        BarSegment(accident.toFloat(), RcTheme.colors.negative),
        // Disqualifications are rare; folding them into "other" keeps the bar
        // readable rather than adding a fifth colour for a one-race sliver.
        BarSegment((disqualified + other).toFloat(), RcTheme.colors.textTertiary),
    ).filter { it.value > 0f }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RcShapes.Medium)
            .background(MaterialTheme.colorScheme.surface)
            .padding(Dimens.SM)
            .semantics(mergeDescendants = true) {
                contentDescription = buildString {
                    append("$name, finish rate $ratePercent percent")
                    append(", finished $finished of $starts starts")
                    if (mechanical > 0) append(", $mechanical mechanical")
                    if (accident > 0) append(", $accident accident")
                    if (disqualified > 0) append(", $disqualified disqualified")
                    if (other > 0) append(", $other other")
                }
            },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = RcTheme.colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "$ratePercent%",
                style = MaterialTheme.typography.titleMedium.tabular(),
                fontWeight = FontWeight.Bold,
                color = RcTheme.colors.textPrimary,
            )
        }
        Spacer(Modifier.height(6.dp))
        StackedBar(segments = segments, height = 16.dp)
        Spacer(Modifier.height(4.dp))
        Text(
            text = "$finished / $starts",
            style = MaterialTheme.typography.labelSmall.tabular(),
            color = RcTheme.colors.textTertiary,
        )
    }
}
