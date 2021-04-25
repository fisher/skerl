# app name, the single edit point for the whole Makefile
APP := skerl

UID := `id -u`

EXTRA_OPTS :=

ERL_FLAGS := $(EXTRA_OPTS) \
        +warn_unused_function \
        +warn_bif_clash \
        +warn_deprecated_function \
        +warn_obsolete_guard \
        +warn_shadow_vars \
        +warn_export_vars \
        +warn_unused_records \
        +warn_unused_import \
        -Werror

ERL_LIBS := ${ERL_LIBS}:~/lib/erl

ERTS_CACHE := erts_include
ERTS_INC := $(shell cat $(ERTS_CACHE) 2>/dev/null)

ifndef ERTS_INC
# Find the actual ERTS location to include erl_nif.h
ERTS_INC=$(shell erl -eval 'io:format("~s", [filename:join([code:root_dir(), "erts-" ++ erlang:system_info(version), "include"])])' -noinput -s init stop |tee $(ERTS_CACHE))
endif

C_OPTS := -c -fpic -Ic_src/include -I${ERTS_INC}
#C_OPTS  := -c -fpic -Ic_src/include -I${ERTS_INC} -DDEBUG -Wall -Wextra -pedantic
CC_OPTS := -c -fpic -Ic_src/include -I${ERTS_INC} -DDEBUG -Wall -Wextra -pedantic

L_OPTS := -lstdc++ -shared

COBJ  := $(patsubst c_src/%.c, obj/%.o, $(wildcard c_src/*.c))
CCOBJ := $(patsubst c_src/%.cc, obj/%.o, $(wildcard c_src/*.cc))

# list of erlang sources and beams to make
ERL_SRC := $(wildcard src/*.erl)
BEAMS   := $(patsubst src/%.erl, ebin/%.beam, $(ERL_SRC))

.PHONY: clean

all: $(APP)

$(APP): ebin/$(APP).app priv/$(APP).so $(BEAMS)

$(BEAMS): $(ERL_SRC) ebin
	erlc -o ebin -I include $(ERL_FLAGS) ${ERL_SRC}

# trying to use C++ instead of pure C
priv/$(APP).so: $(COBJ) $(CCOBJ) priv
	gcc -o priv/$(APP).so $(L_OPTS) $(COBJ) $(CCOBJ)

priv:
	mkdir -p priv

# C++ sources
obj/%.o: c_src/%.cc obj
	gcc -o $@ $(CC_OPTS) $<

# pure C sources
obj/%.o: c_src/%.c obj
	gcc -o $@ $(C_OPTS) $<

obj:
	mkdir -p obj

ebin/$(APP).app: src/$(APP).app.src ebin
	cp src/$(APP).app.src ebin/$(APP).app

ebin:
	mkdir -p ebin

# assuming /usr/local/lib is listed in ld.so.conf
# NB: this should be installed by a package manager,
# it's the manual hack for dev env, not meant to be used in prod
install_blob: priv/$(APP).so
	@sudo mkdir -p /usr/local/lib
	@sudo chown $(UID) /usr/local/lib
	@install -m 0644 bin/$(APP).so /usr/local/lib
	@sudo ldconfig

${APP}_test: test/$(APP)_tests.erl
	ERL_LIBS=$(ERL_LIBS) erlc -o ebin -I include test/$(APP)_tests.erl

eunit:	$(APP) $(APP)_test
	erl -noinput -pa ebin \
		-eval 'ok = eunit:test(${APP}_tests)' \
		-s erlang halt

test:	clean eunit

clean:
	@rm -rf obj ebin doc .eunit
	@rm -f priv/$(APP).so erl_crash.dump $(ERTS_CACHE)
