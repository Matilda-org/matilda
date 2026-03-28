import httpx

MAX_COMMENT_LENGTH = 10000


class MatildaClient:
    def __init__(self, api_url: str, api_key: str):
        self.base_url = api_url.rstrip("/")
        self.headers = {"X-API-Key": api_key}

    def get_tasks(self, user_id: int) -> list[dict]:
        url = f"{self.base_url}/apis/tasks"
        params = {"user_id": user_id, "completed": "false", "with_deadline": "true"}
        resp = httpx.get(url, headers=self.headers, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def get_task_detail(self, task_id: int) -> dict:
        url = f"{self.base_url}/apis/tasks/{task_id}"
        resp = httpx.get(url, headers=self.headers, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def ping(self, machine: str):
        url = f"{self.base_url}/apis/opencode-integration/ping"
        resp = httpx.post(url, headers=self.headers, json={"machine": machine}, timeout=10)
        resp.raise_for_status()

    def post_comment(self, task_id: int, content: str) -> dict:
        if len(content) > MAX_COMMENT_LENGTH:
            content = content[:MAX_COMMENT_LENGTH] + "\n\n[... output troncato]"
        url = f"{self.base_url}/apis/tasks/{task_id}/comment"
        body = {"content": content, "service": "matilda-opencode"}
        resp = httpx.post(url, headers=self.headers, json=body, timeout=30)
        resp.raise_for_status()
        return resp.json()
