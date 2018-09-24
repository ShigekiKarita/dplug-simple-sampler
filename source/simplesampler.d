module simplesampler;

/**
Simplest synthesizer example.

Copyright: Guillaume Piolat 2018.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
import std.complex;
import std.math;
import dplug.core, dplug.client;

version (unittest)
{
}
else
{
    import dplug.vst;
    // This create the DLL entry point
    mixin(DLLEntryPoint!());
    // This create the VST entry point
    mixin(VSTEntryPoint!SimpleMonoSynth);
}
    
/// Simplest VST synth you could make.
final class SimpleMonoSynth : dplug.client.Client
{
public:
nothrow:
@nogc:
    import wav;
    WavRIFF _sample;

    ~this()
    {
        // FIXME
        // freeSlice(this._sample.bytes);
    }
    
    this()
    {
        this._sample = WavRIFF.load(`C:\Users\skarita\Desktop\dplug-simple-sampler\resource\WilhelmScream.wav`);
    }

    override PluginInfo buildPluginInfo()
    {
        static immutable PluginInfo pluginInfo = parsePluginInfo(import("plugin.json"));
        return pluginInfo;
    }

    override Parameter[] buildParameters()
    {
        auto params = makeVec!Parameter();
        return params.releaseData();
    }

    override LegalIO[] buildLegalIO()
    {
        auto io = makeVec!LegalIO();
        io.pushBack(LegalIO(0, 1));
        io.pushBack(LegalIO(0, 2));
        return io.releaseData();
    }

    override int maxFramesInProcess() pure const
    {
        return 32; // samples only processed by a maximum of 32 samples
    }

    override void reset(double sampleRate, int maxFrames, int numInputs, int numOutputs)
    {
        _sampleIndex = 0;
        _phase = complex(1, 0);
        _sampleRate = sampleRate;
        _voiceStatus.initialize();
    }

    override void processAudio(const(float*)[] inputs, float*[]outputs, int frames, TimeInfo info)
    {
        auto d = this._sample.data!short;
        auto _d = d[$-1]; // ???
        foreach(msg; getNextMidiMessages(frames))
        {
            if (msg.isNoteOn())
                _voiceStatus.markNoteOn(msg.noteNumber());
            else if (msg.isNoteOff())
                _voiceStatus.markNoteOff(msg.noteNumber());
        }

        if (_voiceStatus.isAVoicePlaying)
        {
            float freq = convertMIDINoteToFrequency(_voiceStatus.lastNotePlayed);
            foreach(smp; 0..frames)
            {
                foreach (ch; 0.. outputs.length)
                {
                    auto i = this._sampleIndex * 2 + ch;
                    outputs[ch][smp] = cast(float) d[i % $] / short.max;
                }
                ++this._sampleIndex;
            }
            _phase /= abs!float(_phase); // resync oscillator
        }
        else
        {
            outputs[0][0..frames] = 0;
        }
    }

private:
    VoicesStatus _voiceStatus;
    Complex!float _phase;
    float _sampleRate;
    size_t _sampleIndex;
}

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


unittest
{
    import wav;
    auto w = WavRIFF.load(`C:\Users\skarita\Desktop\dplug-simple-sampler\resource\WilhelmScream.wav`);
}
