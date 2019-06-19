package io.pc18.webrtc;



import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;


@Controller
public class HomeController {

	@RequestMapping(value = "/webrtctest", method = RequestMethod.GET)
	public String home(Model model) {
		return "test";
	}

}
