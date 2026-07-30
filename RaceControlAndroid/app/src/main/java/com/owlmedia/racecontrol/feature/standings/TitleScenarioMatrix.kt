package com.owlmedia.racecontrol.feature.standings

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.owlmedia.racecontrol.core.design.Dimens
import com.owlmedia.racecontrol.core.design.RcPalette
import com.owlmedia.racecontrol.core.design.RcTheme
import com.owlmedia.racecontrol.core.ui.RcCard
import com.owlmedia.racecontrol.data.remote.dto.TitleScenariosResponseDto
import com.owlmedia.racecontrol.data.repository.RaceControlRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

@HiltViewModel
class TitleScenariosViewModel @Inject constructor(
    private val repository: RaceControlRepository,
) : ViewModel() {
    private val _data = MutableStateFlow<TitleScenariosResponseDto?>(null)
    val data = _data.asStateFlow()
    fun load(year: Int) {
        if (_data.value?.year == year) return
        viewModelScope.launch { repository.titleScenarios(year).onSuccess { _data.value = it } }
    }
}

@Composable
fun TitleScenarioMatrix(
    year: Int,
    viewModel: TitleScenariosViewModel = hiltViewModel(),
) {
    val data by viewModel.data.collectAsStateWithLifecycle()
    LaunchedEffect(year) { viewModel.load(year) }
    val value = data ?: return
    if (!value.available || value.drivers.size < 2) return
    RcCard {
        Column(Modifier.padding(Dimens.SM)) {
            Text("TITLE PERMUTATIONS", color = RcTheme.colors.textSecondary)
            Text(
                "Rows: ${value.drivers[0].code}. Columns: ${value.drivers[1].code}.",
                color = RcTheme.colors.textTertiary,
            )
            value.clinchText?.let { Text(it, color = RcTheme.colors.positive, modifier = Modifier.padding(vertical = 6.dp)) }
            Canvas(Modifier.fillMaxWidth().height(310.dp)) {
                val count = value.positions.size.coerceAtLeast(1)
                val cell = minOf(size.width, size.height) / count
                val byKey = value.cells.associateBy { it.d1Position to it.d2Position }
                value.positions.forEachIndexed { row, d1 ->
                    value.positions.forEachIndexed { column, d2 ->
                        val outcome = byKey[d1 to d2]?.outcome
                        val color = when (outcome) {
                            "D1_CLINCHED" -> RcPalette.Positive
                            "D2_CLINCHED" -> RcPalette.Negative
                            "D1_LEADS" -> RcPalette.Positive.copy(alpha = 0.35f)
                            "D2_LEADS" -> RcPalette.Negative.copy(alpha = 0.35f)
                            else -> RcPalette.TextTertiary.copy(alpha = 0.55f)
                        }
                        drawRect(
                            color,
                            Offset(column * cell + 1, row * cell + 1),
                            Size(cell - 2, cell - 2),
                        )
                    }
                }
            }
        }
    }
}
