package io.pc18.webrtc;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import org.apache.log4j.LogManager;
import org.apache.log4j.Logger;
import org.json.JSONObject;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;


/*
 * spring websocket 버전 (pom에 추가해야됨)
 * - context에 SocketHandler bean 생성하고 websocket 등록 (servlet-context.xml 참고)
 * - 화상통신의 경우 무조건 ssl을 사용해야함 (server를 ssl로 설정해야됨) (key 발급해야됨)
 * - 간단하게 <Connector SSLEnabled="true" keystoreFile="C:/Users/pc18/tmp/roger.keystore(발급받은키)" keystorePass="123456" port="8443" scheme="https" secure="true" sslProtocol="TLS"/>
 * - 위에걸로 사용하면 서버 Timeout 설정을 늘려야함 (default는 40초)
 * - https로 접속하면 socket도 wss로 접속해야함
 * - cross domain으로 소켓접속은 불가 (https 접속도메인과 wss 접속도메인이 같아야함)
 */

public class SocketHandler extends TextWebSocketHandler {
	
	private final Logger logger = LogManager.getLogger(getClass());
	
	// 연결된 peer에 이름주기 (peer id)
	private static Map<String, WebSocketSession> sessions = Collections.synchronizedMap(new HashMap<String, WebSocketSession>());
	
	// 서로 연결된 peer들 저장 (서로간 연결 성립시)
	private static Map<WebSocketSession, WebSocketSession> sessionConnections = Collections.synchronizedMap(new HashMap<WebSocketSession, WebSocketSession>());

	public SocketHandler() {
		this.logger.info("SocketHandler 생성됨...");
	}
	
	// json To map
	private static Map<String, Object> jsonStrToMap(String jsonStr) {
		System.out.println("요청 메세지 : " + jsonStr);
		JSONObject json = new JSONObject(jsonStr.replace("\n", ""));
		return json.toMap();
	}
	
	// map To json
	private static String mapToJsonStr(Map<String, Object> map) {
		JSONObject json = new JSONObject();
		for(String key : map.keySet()){
			Object val = map.get(key);
			json.put(key, val);
		}
		return json.toString();
	}
	
	// get name By session
	private static String getNameBySession(WebSocketSession session) {
		for(String key : sessions.keySet()){
			WebSocketSession val = sessions.get(key);
			if(val == session) return key;
		}
		return null;
	}
	
	// connection 삭제 (peer와 연결해제)
	@Override
	public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
		//sessions.remove(getNameBySession(session));
		sessions.remove("test");
		this.logger.info("remove session!");
	}
	
	// connection 생성 (peer가 접속함)
	@Override
	public void afterConnectionEstablished(WebSocketSession session)
			throws Exception {
		this.logger.info("add session!");
		sessions.put("test", session);
	}
	
	/* 
	 * 요청 메시지 핸들링
	 * 메시지는 json 타입
	 * 메세지의 type값 : 요청타입을 의미
	 * 메세지의 name값 : type이 login, leave일 경우 >> 자신, 아닐경우 >> 상대방 (내가 연결할)
	 * 메세지의 offer, answer 값 : sdp를 의미
	 * 메세지의 candidate 값 : candidate 의미 (통신을 위한 서로간 프로토콜 옵션 동기화 데이터)
	 * 메세지의 leave 값 : 로그아웃을 의미 (세션제거)
	 */
	@Override
	public void handleMessage(WebSocketSession session,
			WebSocketMessage<?> message) throws Exception {
		
		// 요청 데이터
		Map<String, Object> data = jsonStrToMap(message.getPayload().toString());
		String type = (String) data.get("type");
		String name = (String) data.get("name");
		
		
		// 응답 데이터
		Map<String, Object> result = new HashMap<String, Object>();
		
		
		// login
		if(type.equals("login")){
			System.out.println("사용자 로그인됨 : " + name);
			result.put("type", "login");
			if(sessions.containsKey(name)){
				result.put("success", "false");
			} else {
				sessions.put(name, session);
				result.put("success", "true");
			}
			session.sendMessage(new TextMessage(mapToJsonStr(result)));
		} else
		
		
		// offer
		if(type.equals("offer")){
			String myName = getNameBySession(session);
			System.out.println(myName + "이/가 연결요청함, 상대방 : " + name);
			Object offer = data.get("offer");
			System.out.println("Offer data : " + offer);
			WebSocketSession target = sessions.get(name);
			if(target != null) {
				sessionConnections.put(session, target);
				result.put("type", "offer");
				result.put("offer", offer);
				result.put("name", myName);
				TextMessage response = new TextMessage(mapToJsonStr(result));
				System.out.println("연결요청 데이터 보냄 : " + response);
				target.sendMessage(response);
			}
		} else 
		
		// answer
		if(type.equals("answer")){
			System.out.println("응답요청함, 상대방 : " + name);
			Object answer = data.get("answer");
			WebSocketSession target = sessions.get(name);
			if(target != null) {
				sessionConnections.put(session, target);
				result.put("type", "answer");
				result.put("answer", answer);
				target.sendMessage(new TextMessage(mapToJsonStr(result)));
			}
		} else
		
		// candidate
		if(type.equals("candidate")){
			System.out.println("Sending candidate to : " + name);
			Object candidate = data.get("candidate");
			WebSocketSession target = sessions.get(name);
			if(target != null) {
				result.put("type", "candidate");
				result.put("candidate", candidate);
				target.sendMessage(new TextMessage(mapToJsonStr(result)));
			}
		} else 
			
		// leave
		if(type.equals("leave")) {
			System.out.println("Disconnecting from : " + name);
			WebSocketSession target = sessions.get(name);
			sessionConnections.put(target, null);
			if(target != null){
				result.put("type", "leave");
				target.sendMessage(new TextMessage(mapToJsonStr(result)));
			}
		} else 
			
		// message error
		{
			result.put("type", "error");
			result.put("message", "Command not found: " + type);
			session.sendMessage(new TextMessage(mapToJsonStr(result)));
		}
		
		
	}

	
	// socket error
	@Override
	public void handleTransportError(WebSocketSession session,
			Throwable exception) throws Exception {
		this.logger.error("소켓 에러남!!", exception);
	}
	
	
	
	// echo
	public void sendMessage(String message) {
		// 모든 connection에 보내기
//		for (WebSocketSession session : this.sessionSet) {
//			if (session.isOpen()) {
//				try {
//					session.sendMessage(new TextMessage(message));
//				} catch (Exception ignored) {
//					this.logger.error("fail to send message!", ignored);
//				}
//			}
//		}
	}

	

}
