module simplesampler;

/**
Simplest sampler example.

Copyright: Shigeki Karita, Guillaume Piolat 2018.
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
    mixin(VSTEntryPoint!SimpleSampler);
}
    
/// Simplest VST synth you could make.
final class SimpleSampler : dplug.client.Client
{
private:
nothrow:
@nogc:
    import wav;
    WavRIFF _sample;
    VoicesStatus _voiceStatus;
    float _sampleRate;
    size_t[128] _sampleIndex;
    float[][2][128] _resampled;

public:

    this()
    {
        import resampling;
        this._sample = WavRIFF.load(`C:\Users\skarita\Desktop\dplug-simple-sampler\resource\WilhelmScream.wav`);
        auto srcFreq = 440;
        auto ds = this._sample.data!short;
        auto srcL = makeVec!float(ds.length / 2);
        auto srcR = makeVec!float(ds.length / 2);

        foreach (i; 0 .. srcL.length)
        {
            srcL[i] = cast(float) ds[2 * i] / short.max;
            srcR[i] = cast(float) ds[2 * i + 1] / short.max;
        }
        foreach (n; 0 .. 128)
        {
            auto dstFreq = convertMIDINoteToFrequency(n);
            this._resampled[n][0] = linearInterpolate(srcL[], srcFreq, dstFreq);
            this._resampled[n][1] = linearInterpolate(srcR[], srcFreq, dstFreq);
        }
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
        _sampleIndex[] = 0;
        _sampleRate = sampleRate;
        _voiceStatus.initialize();
    }

    override void processAudio(const(float*)[] inputs, float*[]outputs, int frames, TimeInfo info)
    {
        auto d = this._sample.data!short;
        foreach(msg; getNextMidiMessages(frames))
        {
            if (msg.isNoteOn())
            {
                _voiceStatus.markNoteOn(msg.noteNumber());
                _sampleIndex[msg.noteNumber()] = 0;
            }
            else if (msg.isNoteOff())
                _voiceStatus.markNoteOff(msg.noteNumber());
        }

        if (_voiceStatus.isAVoicePlaying)
        {
            auto note = _voiceStatus.lastNotePlayed;
            auto rs = this._resampled[note];
            foreach(smp; 0..frames)
            {
                foreach (ch; 0.. outputs.length)
                {
                    auto i = _sampleIndex[note];
                    outputs[ch][smp] = rs[ch][i % $];
                }
                ++_sampleIndex[note];
            }
        }
        else
        {
            outputs[0][0..frames] = 0;
        }
    }
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
    auto c = new SimpleSampler;
    int[2][3] i;
    assert(i[2][1] == 0);
}
