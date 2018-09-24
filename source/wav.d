module wav;

@nogc:
nothrow:

/// http://soundfile.sapp.org/doc/WaveFormat/
struct WavRIFF
{
    struct Header {
        // RIFF header
        char[4] riffId;
        int chunkSize;
        char[4] waveId;
        char[4] fmtId;
        int fmtSize;
        short fmtCode;
        short numChannels;
        int sampleRate;
        int bytePerSecond;
        short blockBoundary;
        short bitPerSample;
        char[4] dataId;
        int fileSize;
    }
    Header* header;
    alias header this;
    byte* ptr;

    @disable this(this);
    @disable new(size_t);

    ~this() nothrow @nogc
    {
        import core.stdc.stdlib;
        free(this.header);
    }
    
    auto data(T=byte)() pure nothrow @nogc
    {
        auto p = cast(T*) this.ptr;
        return p[0 .. this.fileSize / (T.sizeof / byte.sizeof)];
    }

    static load(ubyte[] bytes) pure nothrow @nogc
    {
        auto p = cast(Header*) bytes.ptr;
        return typeof(this)(p, cast(byte*)  bytes.ptr + p.sizeof);
    }
    
    static load(const(char)[] fileNameZ) nothrow @nogc
    {
        import dplug.core.file : readFile;
        return load(readFile(fileNameZ));
    }
}

unittest
{
    auto wav = WavRIFF.load("resource/WilhelmScream.wav");
    with (wav)
    {
        assert(riffId == "RIFF");
        assert(waveId == "WAVE");
        assert(fmtId == "fmt ");
        assert(fmtSize == 16); // default
        assert(fmtCode == 1); // default
        assert(numChannels == 2);
        assert(sampleRate == 44100);
        assert(bytePerSecond == sampleRate * blockBoundary);
        assert(blockBoundary == 4);
        assert(bitPerSample == 16);
        assert(dataId == "data");
        assert(data!short[0] == 16727);
        assert(data!short[$-1] == 614);
    }
}
