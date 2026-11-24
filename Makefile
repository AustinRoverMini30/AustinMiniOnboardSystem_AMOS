QML_FILES := $(shell find src -type f -name '*.qml')

.PHONY: format format-check lint

format:
	qmlformat-qt6 -i $(QML_FILES)

format-check:
	@for file in $(QML_FILES); do \
		if ! qmlformat-qt6 "$$file" | diff -u "$$file" -; then \
			echo "QML formatting check failed for $$file"; \
			exit 1; \
		fi; \
	done

lint:
	qmllint-qt6 $(QML_FILES)
