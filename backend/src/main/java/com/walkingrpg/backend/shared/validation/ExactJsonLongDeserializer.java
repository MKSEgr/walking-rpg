package com.walkingrpg.backend.shared.validation;

import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.deser.std.StdScalarDeserializer;

public final class ExactJsonLongDeserializer extends StdScalarDeserializer<Long> {

    public ExactJsonLongDeserializer() {
        super(Long.class);
    }

    @Override
    public Long deserialize(
            JsonParser parser,
            DeserializationContext context
    ) throws JacksonException {
        if (!parser.hasToken(JsonToken.VALUE_NUMBER_INT)
                && !parser.hasToken(JsonToken.VALUE_NUMBER_FLOAT)) {
            return (Long) context.handleUnexpectedToken(Long.class, parser);
        }
        try {
            return parser.getDecimalValue().longValueExact();
        } catch (ArithmeticException exception) {
            return context.reportInputMismatch(
                    this,
                    "Ожидается точное целое JSON-число в диапазоне signed 64-bit"
            );
        }
    }
}
