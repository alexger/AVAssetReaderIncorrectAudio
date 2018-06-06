# AVAssetReaderIncorrectAudio
Sample iOS project to trigger a bug in AVAssetReader when reading audio in AVComposition.

Audio sample buffers read after a call to `-[AVAssetReaderOutput resetTimeRanges:]` when reading an audio track of `AVComposition`
will be incorrect. Edits applied to `AVComposition` will be ignored and the original data will be read. 

In particular, it means that SloMo videos will be read incorectly, because they are represented by `AVComposition`.

See the code in `ViewController.m`
