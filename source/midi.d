module midi;


// Maintain list of active voices/notes
struct VoicesStatus
{
nothrow:
@nogc:

    // Reset state
    void initialize()
    {
        _played[] = 0;
        _currentNumberOfNotePlayed = 0;
        _timestamp = 0;
    }

    bool isAVoicePlaying()
    {
        return _currentNumberOfNotePlayed > 0;
    }

    int lastNotePlayed()
    {
        return _lastNotePlayed;
    }

    // useful to maintain list of msot recently played note
    void timeHasElapsed(int frames)
    {
        _timestamp += frames;
    }

    void markNoteOn(int note)
    {
        _lastNotePlayed = note;

        _played[note]++;
        _currentNumberOfNotePlayed++;

        _timestamps[note] = _timestamp;
    }

    void markNoteOff(int note)
    {
        if (_played[note] > 0)
        {
            _played[note]--;
            _currentNumberOfNotePlayed--;
            if (_currentNumberOfNotePlayed > 0)
                lookForMostRecentlyPlayedActiveNote();
        }
    }

private:

    int _currentNumberOfNotePlayed;

    int _lastNotePlayed;
    int _timestamp;

    int[128] _played;
    int[128] _timestamps;


    // looking for most recently played note still in activity
    void lookForMostRecentlyPlayedActiveNote()
    {
        assert(_currentNumberOfNotePlayed > 0);
        int mostRecent = int.min; // will wrap in 26H, that would be a long note
        for (int n = 0; n < 128; n++)
        {
            if (_played[n] && _timestamps[n] > mostRecent)
            {
                mostRecent = _timestamps[n];
                _lastNotePlayed = n;
            }
        }
    }
}
