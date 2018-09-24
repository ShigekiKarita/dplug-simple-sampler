module wav;

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

    auto bytes() pure nothrow @nogc
    {
        auto b = cast(ubyte*) this.header;
        // FIXME
        version (X86_64)
            auto l = typeof(this).sizeof + this.fileSize - 12;
        else
            auto l = typeof(this).sizeof + this.fileSize - 4;
        
        return b[0 .. l];
    }

    static load(ubyte[] bytes) nothrow @nogc
    {
        auto p = cast(Header*) bytes.ptr;
        return typeof(this)(p, cast(byte*)  bytes.ptr + p.sizeof);
        // import core.stdc.stdio;
        // import std.algorithm : move;
        // printf("%d %d\n", ret.bytes.length, bytes.length);
        // assert(ret.bytes.length == bytes.length);
        // return move(ret);
    }
    
    static load(const(char)[] fileNameZ) nothrow @nogc
    {
        import dplug.core.file : readFile;
        return load(readFile(fileNameZ));
    }
}

unittest
{
    import std.stdio;
    import dplug.core.file;
    auto wav = WavRIFF.load("resource/WilhelmScream.wav");
    with (wav)
    {
        assert(riffId == "RIFF");
        assert(waveId == "WAVE");
        // assert(wav.bytes.length == riffId.length + chunkSize.sizeof + chunkSize);
        assert(fmtId == "fmt ");
        assert(fmtSize == 16); // default
        assert(fmtCode == 1); // default
        assert(numChannels == 2);
        assert(sampleRate == 44100);
        assert(bytePerSecond == sampleRate * blockBoundary);
        assert(blockBoundary == 4);
        assert(bitPerSample == 16);
        assert(dataId == "data");
        // assert(fileSize == bytes.length - (*wav).sizeof + ptr.sizeof);
    }
    assert(wav.data!short[0] == 16727);
    assert(wav.data!short[$-1] == 614);
}
