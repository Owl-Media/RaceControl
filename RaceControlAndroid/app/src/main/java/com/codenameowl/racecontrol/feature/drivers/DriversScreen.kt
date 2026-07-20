package com.codenameowl.racecontrol.feature.drivers

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CompareArrows
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.codenameowl.racecontrol.R
import com.codenameowl.racecontrol.core.design.Dimens
import com.codenameowl.racecontrol.core.design.RcShapes
import com.codenameowl.racecontrol.core.design.RcTheme
import com.codenameowl.racecontrol.core.design.legibleOnSurface
import com.codenameowl.racecontrol.core.design.tabular
import com.codenameowl.racecontrol.core.design.teamColor
import com.codenameowl.racecontrol.core.ui.DriverAvatar
import com.codenameowl.racecontrol.core.ui.EmptyState
import com.codenameowl.racecontrol.core.ui.FavoriteStar
import com.codenameowl.racecontrol.core.ui.LoadableContent
import com.codenameowl.racecontrol.core.ui.PointsPill
import com.codenameowl.racecontrol.core.ui.RcTabScaffold
import com.codenameowl.racecontrol.core.ui.SeasonPickerChip
import com.codenameowl.racecontrol.core.ui.TeamAccentBar
import com.codenameowl.racecontrol.data.remote.dto.DriverDto
import com.codenameowl.racecontrol.feature.AppState

@Composable
fun DriversScreen(
    appState: AppState,
    onSelectYear: (Int) -> Unit,
    onOpenDriver: (String) -> Unit,
    onOpenHeadToHead: () -> Unit,
    viewModel: DriversViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val query by viewModel.query.collectAsStateWithLifecycle()
    val favorites by viewModel.favoriteIds.collectAsStateWithLifecycle()

    LaunchedEffect(appState.selectedYear) { viewModel.load(appState.selectedYear) }

    RcTabScaffold(
        title = stringResource(R.string.tab_drivers),
        actions = {
            IconButton(onClick = onOpenHeadToHead) {
                Icon(
                    imageVector = Icons.Filled.CompareArrows,
                    contentDescription = stringResource(R.string.head_to_head),
                )
            }
            SeasonPickerChip(
                seasons = appState.seasons,
                selected = appState.selectedYear,
                onSelect = onSelectYear,
            )
            Spacer(Modifier.width(Dimens.SM))
        },
    ) { modifier ->
        Column(modifier) {
            OutlinedTextField(
                value = query,
                onValueChange = viewModel::setQuery,
                label = { Text(stringResource(R.string.search_drivers)) },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
                    imeAction = ImeAction.Search,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Dimens.MD, vertical = Dimens.SM),
            )

            LoadableContent(
                state = state,
                onRetry = { viewModel.load(appState.selectedYear, force = true) },
            ) { drivers ->
                when {
                    drivers.isEmpty() && query.isNotBlank() -> EmptyState(
                        icon = Icons.Filled.Search,
                        title = stringResource(R.string.no_search_results_title),
                        message = stringResource(R.string.no_search_results_message, query),
                    )
                    drivers.isEmpty() -> EmptyState(
                        icon = Icons.Filled.Groups,
                        title = stringResource(R.string.no_drivers_title),
                        message = stringResource(
                            R.string.no_drivers_message,
                            appState.selectedYear.toString(),
                        ),
                    )
                    else -> LazyColumn(
                        contentPadding = PaddingValues(Dimens.MD),
                        verticalArrangement = Arrangement.spacedBy(Dimens.SM),
                    ) {
                        items(
                            items = drivers,
                            key = { it.driverId },
                            contentType = { "driver" },
                        ) { driver ->
                            DriverRow(
                                driver = driver,
                                isFavorite = driver.driverId in favorites,
                                onToggleFavorite = { viewModel.toggleFavorite(driver.driverId) },
                                onClick = { onOpenDriver(driver.driverId) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DriverRow(
    driver: DriverDto,
    isFavorite: Boolean,
    onToggleFavorite: () -> Unit,
    onClick: () -> Unit,
) {
    val accent = teamColor(driver.teamColor).legibleOnSurface()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RcShapes.Medium)
            .background(MaterialTheme.colorScheme.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = Dimens.SM, vertical = Dimens.SM),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Dimens.SM),
    ) {
        driver.positionInt?.let {
            Text(
                text = it.toString(),
                style = MaterialTheme.typography.titleMedium.tabular(),
                fontWeight = FontWeight.Bold,
                color = RcTheme.colors.textSecondary,
                modifier = Modifier.width(24.dp),
            )
        }
        TeamAccentBar(color = accent, height = 40.dp)
        DriverAvatar(
            url = driver.headshotUrl,
            initials = driver.initials,
            accent = accent,
            size = 44.dp,
        )
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = driver.fullName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = RcTheme.colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                driver.numberString?.let {
                    Text(
                        text = " #$it",
                        style = MaterialTheme.typography.labelMedium.tabular(),
                        color = accent,
                    )
                }
            }
            Text(
                text = driver.teamName.orEmpty(),
                style = MaterialTheme.typography.bodySmall,
                color = RcTheme.colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        PointsPill(points = driver.pointsString)
        FavoriteStar(isFavorite = isFavorite, onToggle = onToggleFavorite)
    }
}
