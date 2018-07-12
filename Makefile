export

SHELL := /bin/bash
LOCAL := /usr/local
PATH := $(LOCAL)/bin:$(PATH)
TESSDATA =  $(LOCAL)/share/tessdata 
LANGDATA = $(PWD)/langdata-$(LANGDATA_VERSION)

# Name of the model to be built
MODEL_NAME = eng

# No of cores to use for compiling leptonica/tesseract
CORES = 4

# Leptonica version. Default: $(LEPTONICA_VERSION)
LEPTONICA_VERSION := 1.75.3

# Tesseract commit. Default: $(TESSERACT_VERSION)
TESSERACT_VERSION := 9ae97508aed1e5508458f1181b08501f984bf4e2

# Tesseract langdata version. Default: $(LANGDATA_VERSION)
LANGDATA_VERSION := master

# Tesseract model repo to use. Default: $(TESSDATA_REPO)
TESSDATA_REPO = _fast

# Train directory
TRAIN := data/train

# ICDAR data directory
ICDAR_DATA := data/icdar

# Existing model in case fine tuning
TRAINED_MODEL := $(LOCAL)/share/tessdata/$(MODEL_NAME).traineddata

# BEGIN-EVAL makefile-parser --make-help Makefile

help:
	@echo ""
	@echo "  Targets"
	@echo ""
	@echo "    unicharset       Create unicharset"
	@echo "    lists            Create lists of lstmf filenames for training and eval"
	@echo "    training         Start training"
	@echo "    finetune         Start training from an existing model"
	@echo "    proto-model      Build the proto model"
	@echo "    leptonica        Build leptonica"
	@echo "    tesseract        Build tesseract"
	@echo "    tesseract-langs  Download tesseract-langs"
	@echo "    langdata         Download langdata"
	@echo "    clean            Clean all generated files"
	@echo "    convert          Convert ICDAR formated dataset to the useful format"
	@echo ""
	@echo "  Variables"
	@echo ""
	@echo "    MODEL_NAME         Name of the model to be built"
	@echo "    CORES              No of cores to use for compiling leptonica/tesseract"
	@echo "    LEPTONICA_VERSION  Leptonica version. Default: $(LEPTONICA_VERSION)"
	@echo "    TESSERACT_VERSION  Tesseract commit. Default: $(TESSERACT_VERSION)"
	@echo "    LANGDATA_VERSION   Tesseract langdata version. Default: $(LANGDATA_VERSION)"
	@echo "    TESSDATA_REPO      Tesseract model repo to use. Default: $(TESSDATA_REPO)"
	@echo "    TRAIN              Train directory"
	@echo "    RATIO_TRAIN        Ratio of train / eval training data"
	@echo "    ICDAR_DATA         ICDAR Data folder tobe converted"

# END-EVAL

# Ratio of train / eval training data
RATIO_TRAIN := 0.9

ALL_BOXES = data/all-boxes
ALL_LSTMF = data/all-lstmf

# Create unicharset
unicharset: data/unicharset

# Create lists of lstmf filenames for training and eval
lists: $(ALL_LSTMF) data/list.train data/list.eval

data/list.train: $(ALL_LSTMF)
	total=`cat $(ALL_LSTMF) | wc -l` \
	   no=`echo "$$total * $(RATIO_TRAIN) / 1" | bc`; \
	   head -n "$$no" $(ALL_LSTMF) > "$@"

data/list.eval: $(ALL_LSTMF)
	total=`cat $(ALL_LSTMF) | wc -l` \
	   no=`echo "($$total - $$total * $(RATIO_TRAIN)) / 1" | bc`; \
	   tail -n "+$$no" $(ALL_LSTMF) > "$@"

# Start training
training: data/$(MODEL_NAME).traineddata

data/unicharset: $(ALL_BOXES)
	unicharset_extractor --output_unicharset "$@" --norm_mode 1 "$(ALL_BOXES)"

$(ALL_BOXES): $(sort $(patsubst %.tif,%.box,$(wildcard $(TRAIN)/*.tif)))
	find $(TRAIN) -name '*.box' -exec cat {} \; > "$@"

$(TRAIN)/%.box: $(TRAIN)/%.tif $(TRAIN)/%.gt.txt
	./generate_line_box.py -i "$(TRAIN)/$*.tif" -t "$(TRAIN)/$*.gt.txt" |tee "$@"

$(ALL_LSTMF): $(sort $(patsubst %.tif,%.lstmf,$(wildcard $(TRAIN)/*.tif)))
	find $(TRAIN) -name '*.lstmf' -exec echo {} \; | sort -R -o "$@"

$(TRAIN)/%.lstmf: $(TRAIN)/%.box
	tesseract $(TRAIN)/$*.tif $(TRAIN)/$* lstm.train

# Build the proto model
proto-model: data/$(MODEL_NAME)/$(MODEL_NAME).traineddata

data/$(MODEL_NAME)/$(MODEL_NAME).traineddata: langdata data/unicharset
	combine_lang_model \
	  --input_unicharset data/unicharset \
	  --script_dir $(LANGDATA) \
	  --output_dir data/ \
	  --lang $(MODEL_NAME)

data/checkpoints/$(MODEL_NAME)_checkpoint: unicharset lists proto-model
	mkdir -p data/checkpoints
	lstmtraining \
	  --traineddata data/$(MODEL_NAME)/$(MODEL_NAME).traineddata \
	  --net_spec "[1,36,0,1 Ct3,3,16 Mp3,3 Lfys48 Lfx96 Lrx96 Lfx256 O1c`head -n1 data/unicharset`]" \
	  --model_output data/checkpoints/$(MODEL_NAME) \
	  --learning_rate 20e-4 \
	  --train_listfile data/list.train \
	  --eval_listfile data/list.eval \
	  --max_iterations 10000

data/$(MODEL_NAME).traineddata: data/checkpoints/$(MODEL_NAME)_checkpoint
	lstmtraining \
	--stop_training \
	--continue_from $^ \
	--traineddata data/$(MODEL_NAME)/$(MODEL_NAME).traineddata \
	--model_output $@

# Start finetuning
finetune: lists
	mkdir -p data/checkpoints
	combine_tessdata -e $(TRAINED_MODEL) ./data/$(MODEL_NAME).lstm
	lstmtraining \
	--continue_from ./data/$(MODEL_NAME).lstm \
	--traineddata $(TRAINED_MODEL) \
	--train_listfile data/list.train \
	--eval_listfile data/list.eval \
	--model_output ./data/checkpoints/$(MODEL_NAME) \
	--max_iterations 10000
	lstmtraining \
	--stop_training \
	--continue_from ./data/checkpoints/$(MODEL_NAME)_checkpoint \
	--traineddata $(TRAINED_MODEL) \
	--model_output ./data/$(MODEL_NAME).traineddata

# Build leptonica
leptonica: leptonica.built

leptonica.built: leptonica-$(LEPTONICA_VERSION)
	cd $< ; \
		./configure --prefix=$(LOCAL) && \
		make -j$(CORES) && \
		make install && \
		date > "$@"

leptonica-$(LEPTONICA_VERSION): leptonica-$(LEPTONICA_VERSION).tar.gz
	tar xf "$<"

leptonica-$(LEPTONICA_VERSION).tar.gz:
	wget 'http://www.leptonica.org/source/$@'

# Build tesseract
tesseract: tesseract.built tesseract-langs

tesseract.built: tesseract-$(TESSERACT_VERSION)
	cd $< && \
		sh autogen.sh && \
		PKG_CONFIG_PATH="$(LOCAL)/lib/pkgconfig" \
		LEPTONICA_CFLAGS="-I$(LOCAL)/include/leptonica" \
			./configure --prefix=$(LOCAL) && \
		LDFLAGS="-L$(LOCAL)/lib"\
			make -j$(CORES) && \
		make install && \
		make -j$(CORES) training-install && \
		date > "$@"

tesseract-$(TESSERACT_VERSION):
	wget https://github.com/tesseract-ocr/tesseract/archive/$(TESSERACT_VERSION).zip
	unzip $(TESSERACT_VERSION).zip

# Download tesseract-langs
tesseract-langs: $(TESSDATA)/eng.traineddata

# Download langdata
langdata:
	if [ ! -e ./$(LANGDATA_VERSION).zip ]; then \
		wget 'https://github.com/tesseract-ocr/langdata/archive/$(LANGDATA_VERSION).zip' --no-check-certificate; \
		unzip $(LANGDATA_VERSION).zip; \
	fi;

$(TESSDATA)/eng.traineddata:
	cd $(TESSDATA) && wget https://github.com/tesseract-ocr/tessdata$(TESSDATA_REPO)/raw/master/$(notdir $@)

# Convert ICDAR to TESS
convert:
	python convert_icdar.py -i "$(ICDAR_DATA)" -o "$(TRAIN)"

# Clean all generated files
clean:
	find data/train -name '*.box' -delete
	find data/train -name '*.lstmf' -delete
	rm -rf data/all-*
	rm -rf data/list.*
	rm -rf data/$(MODEL_NAME)
	rm -rf data/unicharset
	rm -rf data/checkpoints
