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
    Header header;
    alias header this;
    byte* ptr;

    auto data(T=byte)() pure nothrow @nogc
    {
        auto p = cast(T*) this.ptr;
        return p[0 .. this.fileSize / (T.sizeof / byte.sizeof)];
    }

    auto bytes() pure nothrow @nogc
    {
        auto b = cast(ubyte*) &this;
        // FIXME
        version (X86_64)
            auto l = typeof(this).sizeof + this.fileSize - 12;
        else
            auto l = typeof(this).sizeof + this.fileSize - 4;
        
        return b[0 .. l];
    }

    static load(ubyte[] bytes)
    {
        auto p = cast(Header*) bytes.ptr;
        import core.stdc.stdio;
        // printf("%d %d\n", p.bytes.length, bytes.length);
        // assert(p.bytes.length == bytes.length);
        return typeof(this)(*p, cast(byte*)  bytes.ptr + p.sizeof);
    }
    
    static load(const(char)[] fileNameZ)
    {
        import dplug.core.file : readFile;
        return load(readFile(fileNameZ));
    }

    // ~this()
    // {
    //     import dplug.core.nogc : freeSlice;
    //     auto p = cast(ubyte*) &this;
    //     freeSlice(p[0 .. typeof(this).sizeof]);
    // }
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
    writeln(wav.data!short[$-1]);
}
