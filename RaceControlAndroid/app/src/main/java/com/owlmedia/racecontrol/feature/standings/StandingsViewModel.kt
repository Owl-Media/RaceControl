package com.owlmedia.racecontrol.feature.standings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.owlmedia.racecontrol.core.ui.UiState
import com.owlmedia.racecontrol.data.remote.dto.ConstructorStandingDto
import com.owlmedia.racecontrol.data.remote.dto.DriverStandingDto
import com.owlmedia.racecontrol.data.remote.dto.ReliabilityResponseDto
import com.owlmedia.racecontrol.data.remote.dto.StandingsEvolutionDto
import com.owlmedia.racecontrol.data.remote.dto.WdcCalculatorDto
import com.owlmedia.racecontrol.data.repository.RaceControlRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class StandingsMode { DRIVERS, TEAMS, PROGRESS, RELIABILITY, WDC }

@HiltViewModel
class StandingsViewModel @Inject constructor(
    private val repository: RaceControlRepository,
) : ViewModel() {

    private val _mode = MutableStateFlow(StandingsMode.DRIVERS)
    val mode: StateFlow<StandingsMode> = _mode.asStateFlow()

    private val _drivers = MutableStateFlow<UiState<List<DriverStandingDto>>>(UiState.Idle)
    val drivers: StateFlow<UiState<List<DriverStandingDto>>> = _drivers.asStateFlow()

    private val _constructors = MutableStateFlow<UiState<List<ConstructorStandingDto>>>(UiState.Idle)
    val constructors: StateFlow<UiState<List<ConstructorStandingDto>>> = _constructors.asStateFlow()

    private val _evolution = MutableStateFlow<UiState<StandingsEvolutionDto>>(UiState.Idle)
    val evolution: StateFlow<UiState<StandingsEvolutionDto>> = _evolution.asStateFlow()

    private val _reliability = MutableStateFlow<UiState<ReliabilityResponseDto>>(UiState.Idle)
    val reliability: StateFlow<UiState<ReliabilityResponseDto>> = _reliability.asStateFlow()

    private val _wdc = MutableStateFlow<UiState<WdcCalculatorDto>>(UiState.Idle)
    val wdc: StateFlow<UiState<WdcCalculatorDto>> = _wdc.asStateFlow()

    private var loadedYear: Int? = null

    fun setMode(value: StandingsMode) {
        _mode.value = value
    }

    /**
     * Only the visible mode is fetched. Progress and Reliability are expensive
     * server-side (they replay the whole season), so loading all four up front
     * would make opening the tab noticeably slower for data most users never
     * look at.
     */
    fun load(year: Int, mode: StandingsMode, force: Boolean = false) {
        if (loadedYear != year) {
            _drivers.value = UiState.Idle
            _constructors.value = UiState.Idle
            _evolution.value = UiState.Idle
            _reliability.value = UiState.Idle
            _wdc.value = UiState.Idle
            loadedYear = year
        }
        when (mode) {
            StandingsMode.DRIVERS -> loadDrivers(year, force)
            StandingsMode.TEAMS -> loadConstructors(year, force)
            StandingsMode.PROGRESS -> loadEvolution(year, force)
            StandingsMode.RELIABILITY -> loadReliability(year, force)
            StandingsMode.WDC -> loadWdc(year, force)
        }
    }

    private fun loadDrivers(year: Int, force: Boolean) {
        if (!force && _drivers.value is UiState.Loaded) return
        viewModelScope.launch {
            _drivers.value = UiState.Loading
            repository.driverStandings(year)
                .onSuccess { _drivers.value = UiState.Loaded(it) }
                .onFailure { _drivers.value = UiState.Failed(repository.messageFor(it)) }
        }
    }

    private fun loadConstructors(year: Int, force: Boolean) {
        if (!force && _constructors.value is UiState.Loaded) return
        viewModelScope.launch {
            _constructors.value = UiState.Loading
            repository.constructorStandings(year)
                .onSuccess { _constructors.value = UiState.Loaded(it) }
                .onFailure { _constructors.value = UiState.Failed(repository.messageFor(it)) }
        }
    }

    private fun loadEvolution(year: Int, force: Boolean) {
        if (!force && _evolution.value is UiState.Loaded) return
        viewModelScope.launch {
            _evolution.value = UiState.Loading
            repository.standingsEvolution(year)
                .onSuccess { _evolution.value = UiState.Loaded(it) }
                .onFailure { _evolution.value = UiState.Failed(repository.messageFor(it)) }
        }
    }

    private fun loadReliability(year: Int, force: Boolean) {
        if (!force && _reliability.value is UiState.Loaded) return
        viewModelScope.launch {
            _reliability.value = UiState.Loading
            repository.reliability(year)
                .onSuccess { _reliability.value = UiState.Loaded(it) }
                .onFailure { _reliability.value = UiState.Failed(repository.messageFor(it)) }
        }
    }

    private fun loadWdc(year: Int, force: Boolean) {
        if (!force && _wdc.value is UiState.Loaded) return
        viewModelScope.launch {
            _wdc.value = UiState.Loading
            repository.wdcCalculator(year)
                .onSuccess { _wdc.value = UiState.Loaded(it) }
                .onFailure { _wdc.value = UiState.Failed(repository.messageFor(it)) }
        }
    }
}
