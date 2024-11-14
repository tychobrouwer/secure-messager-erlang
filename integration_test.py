import subprocess
import threading
import time
import asyncio

NR_CLIENTS = 3
PORT = 4000
TEST_MESSAGE = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed varius metus ut nisl varius tempus. Nullam at cursus nisl. Etiam sit amet neque sem. Quisque ipsum arcu, mollis non leo eu, varius eleifend elit. Morbi quis pretium massa. Curabitur posuere ex enim, eget tincidunt mi commodo nec. Cras non ornare diam. Pellentesque lobortis est augue, ut tincidunt tortor aliquam id. Suspendisse libero ante, sollicitudin id aliquam quis, placerat vel nisl. Vivamus suscipit feugiat pellentesque. Cras rutrum orci non facilisis ultrices."

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
    ENDC =    '\033[0m'

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

                if line == "" or "iex" in line or "Elixir" in line or "Erlang" in line:
                    continue

                line_split = line.split(" ")

                if len(line_split) < 3:
                    print(f"{color}[{self.name}]{bcolors.ENDC} {line}")
                    continue

                if "Error" in line or "error" in line:
                    global errors
                    errors += 1

                color = bcolors.CLIENT
                if "Server" in self.name:
                    color = bcolors.SERVER


                time = line_split[0]

                if time.count(":") != 2:
                    print(f"{color}[{self.name}]{bcolors.ENDC} {line}")
                    continue

                level = line_split[3]
                line = " ".join(line_split[4:])
                metadata = " ".join(line_split[1:3])

                level_color = bcolors.ERROR
                if level == "[info]":
                    level_color = bcolors.OKGREEN
                elif level == "[notice]":
                    level_color = bcolors.NOTICE
                elif level == "[warning]":
                    level_color = bcolors.WARNING

                print(f"{color}[{self.name}]{bcolors.ENDC} {bcolors.TIME}{time}{bcolors.ENDC} {metadata} {level_color}{level}{bcolors.ENDC} {line}")

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

    def signup(self):
        # token = Client.Account.signup(user_id, user_password)
        self.process.send_input(f"token = Client.Account.signup(\"{self.user_id}\", \"password\")")

    def add_contact(self, user_id):
        if user_id == self.user_id:
            return

        # contact_uuid = Client.Contact.add_contact(user_uuid, user_id)
        self.process.send_input(f"Client.Contact.add_contact(:crypto.hash(:sha, \"{user_id}\"))")

    def send_message(self, user_id):
        if user_id == self.user_id:
            return

        # Client.Message.send("Hello World! 1", contact_uuid)
        self.process.send_input(f"Client.Message.send(\"{TEST_MESSAGE}\", :crypto.hash(:sha, \"{user_id}\"))")

    def stop(self):
        self.process.stop()

def create_server_and_clients():
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Starting server...")

    global server
    server = ElixirProcess(" Server ", f"cd ./server && PORT={PORT} iex -S mix run --no-halt")
    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Starting clients...")

    for i in range(NR_CLIENTS):
        clients[i] = Client(i)

    input("")

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Signing up...")

    for i in range(NR_CLIENTS):
        clients[i].signup()

    input("")

def destroy_server_and_clients():
    input("")

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Stopping...")

    for i in range(NR_CLIENTS):
        clients[i].stop()

    server.stop()

    time.sleep(1)

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Done!")
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Errors: {errors}")

def run_elixir_test_1():
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Adding contacts...")

    for i in range(NR_CLIENTS):
        for j in range(NR_CLIENTS):
            clients[i].add_contact(f"user{j}")
        
    input("")

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Sending messages...")

    for i in range(NR_CLIENTS):
        for j in range(NR_CLIENTS):
            clients[j].send_message(f"user{i}")
        
        time.sleep(0.5)

def run_elixir_test_2():
    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Adding contacts...")

    i = 0
    for j in range(NR_CLIENTS):
        clients[j].add_contact(f"user{i}")
    
    input("")

    print(f"{bcolors.OKGREEN}[Process ]{bcolors.ENDC} Sending messages...")

    for j in range(NR_CLIENTS):
        clients[j].send_message(f"user{i}")

if __name__ == "__main__":
    create_server_and_clients()
    run_elixir_test_1()
    destroy_server_and_clients()

    input("")
    
    create_server_and_clients()
    run_elixir_test_2()
    destroy_server_and_clients()
