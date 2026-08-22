package com.tishreen.api;

import com.tishreen.api.testsupport.TestProperties;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = TestProperties.NO_DATABASE)
class TishreenApiApplicationTests {

    @Test
    void contextLoads() {
    }
}
