package com.ddoddo.helloworldv1;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(origins = "http://localhost:3001")
public class HelloController {
    @GetMapping("/")
    public String hello() {
        return "hello world !!!";
    }
}
