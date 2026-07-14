package utils;

import org.apache.avro.Schema;
import tech.allegro.schema.json2avro.converter.JsonAvroConverter;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

/*
* simple Java utility class that reads your .avsc schema file, attempts to convert your JSON payload (from the API response) into Avro, and catches any schema mismatch errors.
*/
public class AvroSchemaValidator {

    public static String validate(String jsonPayload, String schemaPath) {
        try {
            // 1. Load the Avro Schema from class path
            ClassLoader classLoader = AvroSchemaValidator.class.getClassLoader();
            try (InputStream is = classLoader.getResourceAsStream(schemaPath)) {
                if (is == null) {
                    return "Schema file not found at: " + schemaPath;
                }
                String schemaJson = new String(is.readAllBytes(), StandardCharsets.UTF_8);
                Schema schema = new Schema.Parser().parse(schemaJson);

                // 2. Attempt to convert JSON to Avro bytes (this triggers full schema validation)
                JsonAvroConverter converter = new JsonAvroConverter();
                converter.convertToAvro(jsonPayload.getBytes(StandardCharsets.UTF_8), schema);
                
                // If it succeeds, return "SUCCESS"
                return "SUCCESS";
            }
        } catch (Exception e) {
            // Return the validation error message back to Karate
            return e.getMessage();
        }
    }
}
