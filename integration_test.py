import subprocess
import threading
import time
import asyncio

NR_CLIENTS = 10
PORT = 4011
TEST_MESSAGE = "Hello!"

errors = 0
server = None
clients = [None] * NR_CLIENTS

class bcolors:
    ERROR =   '\033[91m' # Red
    OKGREEN = '\033[92m' # Green
    WARNING = '\033[93m' # Yellow
    SERVER =  '\033[94m' # Blue
    NOTICE =  '\033[95m' # Purple
    CLIENT =  '\033[96m' # Cyan
    TIME =    '\033[90m' # Grey
    ENDC = '\033[0m'

class ElixirProcess:
    def __init__(self, name, command):
        self.name = name
        self.process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1,  # Line-buffered
            shell=True
        )

        # Start a background thread to stream output in real-time
        self.output_thread = threading.Thread(target=self.stream_output)
        self.output_thread.daemon = True
        self.output_thread.start()

    def stream_output(self):
        """Continuously read and print output from the Elixir process."""
        if self.process.stdout:
            for line in iter(self.process.stdout.readline, ""):
                line = line.strip()

                if line == "":
                    continue

                if "Error" in line or "error" in line:
                    global errors
                    errors += 1

                color = bcolors.CLIENT
                if "Server" in self.name:
                    color = bcolors.SERVER

                if len(line.split(" ")) < 3 or "iex" in line or "Interactive Elixir" in line:
                    print(f"{color}[{self.name}]{bcolors.ENDC} {line}")
                    continue

                time = line.split(" ")[0]

                if time.count(":") != 2:
                    print(f"{color}[{self.name}]{bcolors.ENDC} {line}")
                    continue

                level = line.split(" ")[1]
                line = " ".join(line.split(" ")[2:])
                
                level_color = bcolors.ERROR
                if level == "[info]":
                    level_color = bcolors.OKGREEN
                elif level == "[notice]":
                    level_color = bcolors.NOTICE
                elif level == "[warning]":
                    level_color = bcolors.WARNING

                print(f"{color}[{self.name}]{bcolors.ENDC} {bcolors.TIME}{time}{bcolors.ENDC} {level_color}{level}{bcolors.ENDC} {line}")

            self.process.stdout.close()

    def send_input(self, input_data):
        """Send data to the Elixir process."""
        if self.process.stdin:
            self.process.stdin.write(input_data + '\n')
            self.process.stdin.flush()

    def stop(self):
        """Terminate the Elixir process."""
        self.process.stdin.close()
        self.process.terminate()
        self.process.wait()

class Client:
    def __init__(self, id):
        self.id = id
        self.name = f"Client {id}"
        self.process = ElixirProcess(self.name, f"cd ./client && PORT={PORT} iex -S mix run --no-halt")

        self.user_id = f"user{id}"
        user_password = f"password{id}"

        time.sleep(1)

        # token = Client.Account.signup(user_id, user_password)
        self.process.send_input(f"token = Client.Account.signup(\"{self.user_id}\", \"{user_password}\")")

    def add_contact(self, user_id):
        if user_id == self.user_id:
            return

        # contact_uuid = Client.Contact.add_contact(user_uuid, user_id)
        self.process.send_input(f"contact_uuid_{user_id} = Client.Contact.add_contact(nil, \"{user_id}\")")

    def send_message(self, user_id):
        if user_id == self.user_id:
            return

        # Client.Message.send("Hello World! 1", contact_uuid)
        self.process.send_input(f"Client.Message.send(\"{TEST_MESSAGE}\", contact_uuid_{user_id})")

    def stop(self):
        self.process.stop()

def create_server_and_clients():
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Starting server...")

    global server
    server = ElixirProcess(" Server ", f"cd ./server && PORT={PORT} iex -S mix run --no-halt")
    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Adding clients...")

    for i in range(NR_CLIENTS):
        clients[i] = Client(i)

    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Adding contacts...")

def destroy_server_and_clients():
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Stopping...")

    time.sleep(1)

    for i in range(NR_CLIENTS):
        clients[i].stop()

    server.stop()

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Done!")
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Errors: {errors}")

def run_elixir_test_1():
    create_server_and_clients()

    for i in range(NR_CLIENTS):
        for j in range(NR_CLIENTS):
            clients[i].add_contact(f"user{j}")
        
    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Sending messages...")

    i = 0

    for i in range(NR_CLIENTS):
        for j in range(NR_CLIENTS):
            clients[i].send_message(f"user{j}")
        
        time.sleep(1)
    
    destroy_server_and_clients()

def run_elixir_test_2():
    create_server_and_clients()

    i = 0
    for j in range(NR_CLIENTS):
        clients[i].add_contact(f"user{j}")
    
    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Sending messages...")

    i = 0
    for j in range(NR_CLIENTS):
        clients[i].send_message(f"user{j}")

    destroy_server_and_clients()

if __name__ == "__main__":
    run_elixir_test_1()
    time.sleep(10)
    run_elixir_test_2()
