# ocrd-train

Training workflow for Tesseract 4 as a Makefile for dependency tracking and building the required software from source.   

New features:  
- Process for finetuning LSTM network  
- Additional tool: Convert dataset based ICDAR format to the format of this tool.    

## Install

To build leptonica and tesseract, additional data and install it to a subdirectory `./usr` in the repo:

```sh
  make leptonica tesseract langdata
```

## Provide ground truth

Place ground truth consisting of line images and transcriptions in the folder
`data/train` for training and `data/eval` for evaluation.

Images must be TIFF and have the extension `.tif`.

Transcriptions must be single-line plain text and have the same name as the
line image but with `.tif` replaced by `.gt.txt`.

The repository contains a ZIP archive with sample ground truth, see
[ocrd-testset.zip](./ocrd-testset.zip). Extract it to `./data/train` and run
`make training`.

## Train

```
 make training MODEL_NAME=name-of-the-resulting-model
```

which is basically a shortcut for

```
   make unicharset lists proto-model training
```

Run `make help` to see all the possible targets and variables:

<!-- BEGIN-EVAL -w '```' '```' -- make help -->
```

  Targets

    unicharset       Create unicharset
    lists            Create lists of lstmf filenames for training and eval
    training         Start training
    proto-model      Build the proto model
    leptonica        Build leptonica
    tesseract        Build tesseract
    tesseract-langs  Download tesseract-langs
    langdata         Download langdata
    clean            Clean all generated files
    convert          Convert ICDAR formated dataset to the useful format

  Variables

    MODEL_NAME         Name of the model to be built
    CORES              No of cores to use for compiling leptonica/tesseract
    LEPTONICA_VERSION  Leptonica version. Default: 1.75.3
    TESSERACT_VERSION  Tesseract commit. Default: 9ae97508aed1e5508458f1181b08501f984bf4e2
    LANGDATA_VERSION   Tesseract langdata version. Default: master
    TESSDATA_REPO      Tesseract model repo to use. Default: _fast
    TRAIN              Train directory
    RATIO_TRAIN        Ratio of train / eval training data
    ICDAR_DATA         ICDAR Data folder tobe converted
```

<!-- END-EVAL -->

## License

Software is provided under the terms of the `Apache 2.0` license.

Original repository provided by [OCR-D](https://github.com/OCR-D/ocrd-train)
