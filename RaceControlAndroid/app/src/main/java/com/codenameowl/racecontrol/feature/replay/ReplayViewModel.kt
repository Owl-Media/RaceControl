package com.codenameowl.racecontrol.feature.replay

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.codenameowl.racecontrol.core.ui.UiState
import com.codenameowl.racecontrol.data.remote.dto.RaceReplayDto
import com.codenameowl.racecontrol.data.remote.dto.ReplayFrameDto
import com.codenameowl.racecontrol.data.repository.RaceControlRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@HiltViewModel
class ReplayViewModel @Inject constructor(
    private val repository: RaceControlRepository,
) : ViewModel() {

    private val _state = MutableStateFlow<UiState<RaceReplayDto>>(UiState.Idle)
    val state: StateFlow<UiState<RaceReplayDto>> = _state.asStateFlow()

    private val _currentLap = MutableStateFlow(1)
    val currentLap: StateFlow<Int> = _currentLap.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _speed = MutableStateFlow(1.0f)
    val speed: StateFlow<Float> = _speed.asStateFlow()

    private var replay: RaceReplayDto? = null
    private var framesByLap: Map<Int, ReplayFrameDto> = emptyMap()

    /**
     * The playback loop.
     *
     * A coroutine in [viewModelScope] rather than a Timer: it is cancelled
     * automatically when the ViewModel clears, and [stop] is also called when
     * the screen leaves the composition, so playback can never outlive the UI
     * the way a stray Timer would.
     */
    private var playbackJob: Job? = null

    fun load(year: Int, round: Int) {
        if (_state.value is UiState.Loaded) return
        viewModelScope.launch {
            _state.value = UiState.Loading
            repository.replay(year, round)
                .onSuccess { data ->
                    replay = data
                    framesByLap = data.frames.associateBy { it.lap }
                    _currentLap.value = data.frames.firstOrNull()?.lap ?: 1
                    _state.value = UiState.Loaded(data)
                }
                .onFailure { _state.value = UiState.Failed(repository.messageFor(it)) }
        }
    }

    fun frameFor(lap: Int): ReplayFrameDto? =
        framesByLap[lap] ?: framesByLap.filterKeys { it <= lap }.maxByOrNull { it.key }?.value
            ?: framesByLap.minByOrNull { it.key }?.value

    /** Position on the previous lap, used to draw the movement arrows. */
    fun previousPosition(driver: String, lap: Int): Int? {
        if (lap <= 1) return null
        val previous = framesByLap[lap - 1]
            ?: framesByLap.filterKeys { it < lap }.maxByOrNull { it.key }?.value
        return previous?.order?.firstOrNull { it.driver == driver }?.position
    }

    fun scrubTo(lap: Int) {
        val total = replay?.totalLaps ?: return
        _currentLap.value = lap.coerceIn(1, total)
    }

    fun togglePlay() {
        if (_isPlaying.value) stop() else play()
    }

    fun setSpeed(value: Float) {
        _speed.value = value
        if (_isPlaying.value) {
            // Restart the loop so the new interval takes effect immediately.
            startLoop()
        }
    }

    private fun play() {
        val total = replay?.totalLaps ?: return
        if (_currentLap.value >= total) _currentLap.value = 1
        _isPlaying.value = true
        startLoop()
    }

    fun stop() {
        _isPlaying.value = false
        playbackJob?.cancel()
        playbackJob = null
    }

    private fun startLoop() {
        playbackJob?.cancel()
        playbackJob = viewModelScope.launch {
            while (isActive) {
                // 0.9s per lap at 1x, matching the iOS timer interval.
                delay((900L / _speed.value).toLong().coerceAtLeast(50L))
                val total = replay?.totalLaps ?: break
                if (_currentLap.value < total) {
                    _currentLap.value += 1
                } else {
                    stop()
                    break
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stop()
    }
}
