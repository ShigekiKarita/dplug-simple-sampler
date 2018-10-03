module simplesampler;

/**
Simplest sampler example.

Copyright: Shigeki Karita, Guillaume Piolat 2018.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/


import dplug.client : Parameter, Client, DLLEntryPoint;

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
final class SimpleSampler : Client
{
private:
nothrow:
@nogc:

    import dplug.core : mallocNew, makeVec, convertMIDINoteToFrequency;
    import dplug.client : IGraphics, PluginInfo, TimeInfo, LegalIO, parsePluginInfo;

    import wav;
    import midi : VoicesStatus;
    WavRIFF _sample;
    VoicesStatus _voiceStatus;
    float _sampleRate;
    size_t[128] _sampleIndex;
    float[][2][128] _resampled;

public:

    this()
    {
        import resampling : linearInterpolate;
        this._sample = WavRIFF("resource/WilhelmScream.wav");
        // this._sample = WavRIFF(import("WilhelmScream.wav"))); // FIXME
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
                immutable i = _sampleIndex[note];
                foreach (ch; 0.. outputs.length)
                {
                    outputs[ch][smp] = rs[ch][i % $];
                }
                ++_sampleIndex[note];
            }
        }
        else
        {
            foreach (o; outputs)
                o[0..frames] = 0;
        }
    }
}

unittest
{
    auto c = new SimpleSampler;
}
