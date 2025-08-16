import json
import boto3
import base64
import hashlib
import time

ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')
TOKEN_SECRET = 'your-secret-key-change-this'

def get_admin_password():
    response = ssm.get_parameter(Name='/oh/admin-password', WithDecryption=True)
    return response['Parameter']['Value']

def verify_password(password):
    return password == get_admin_password()

def generate_token():
    exp = int(time.time()) + 86400  # 24 hours
    data = f'auth:{exp}'
    signature = hashlib.sha256((data + TOKEN_SECRET).encode()).hexdigest()
    return base64.b64encode(f'{data}:{signature}'.encode()).decode()

def verify_token(token):
    try:
        decoded = base64.b64decode(token).decode()
        parts = decoded.split(':')  # auth:exp:signature
        if len(parts) != 3:
            return False
        auth, exp, signature = parts
        if int(exp) < time.time():  # expired
            return False
        expected_sig = hashlib.sha256((f'{auth}:{exp}' + TOKEN_SECRET).encode()).hexdigest()
        return signature == expected_sig and auth == 'auth'
    except:
        return False

def get_token_from_header(event):
    auth_header = event.get('headers', {}).get('authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    return None

def get_instance_info():
    response = ec2.describe_instances(
        Filters=[{'Name': 'tag:ProjectName', 'Values': ['oh']}]
    )
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            if instance['State']['Name'] != 'terminated':
                return {
                    'id': instance['InstanceId'],
                    'state': instance['State']['Name'],
                    'ip': instance.get('PublicIpAddress', 'N/A'),
                    'sg_id': instance['SecurityGroups'][0]['GroupId'] if instance.get('SecurityGroups') else None
                }
    return None

def add_ip_to_sg(ip_address):
    instance = get_instance_info()
    if not instance:
        return {'success': False, 'error': 'No instance found'}
    if not instance.get('sg_id'):
        return {'success': False, 'error': 'No security group found', 'instance': instance}
    
    try:
        ec2.authorize_security_group_ingress(
            GroupId=instance['sg_id'],
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': f'{ip_address}/32', 'Description': 'Auto-added IP'}]
                },
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 5000,
                    'ToPort': 7000,
                    'IpRanges': [{'CidrIp': f'{ip_address}/32', 'Description': 'Auto-added IP'}]
                }
            ]
        )
        return {'success': True, 'sg_id': instance['sg_id']}
    except Exception as e:
        error_str = str(e)
        if 'InvalidPermission.Duplicate' in error_str:
            return {'success': True, 'message': 'IP already whitelisted', 'sg_id': instance['sg_id']}
        return {'success': False, 'error': error_str, 'sg_id': instance['sg_id']}

def lambda_handler(event, context):
    # Handle both API Gateway and Lambda Function URL events
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method', 'GET')
    path = event.get('path') or event.get('requestContext', {}).get('http', {}).get('path', '/')
    
    # Handle CORS preflight requests
    if method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': ''
        }
    
    # Serve HTML page (no auth required)
    if method == 'GET' and path == '/':
        html = '''<!DOCTYPE html>
<html>
<head>
    <title>AWS Controller</title>
    <style>
        body { font-family: Arial; margin: 40px; background: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; text-align: center; }
        .status { padding: 15px; margin: 20px 0; border-radius: 5px; font-weight: bold; }
        .running { background: #d4edda; color: #155724; }
        .stopped { background: #f8d7da; color: #721c24; }
        .pending { background: #fff3cd; color: #856404; }
        button { padding: 12px 24px; margin: 10px 5px; border: none; border-radius: 5px; cursor: pointer; }
        .start { background: #28a745; color: white; }
        .stop { background: #dc3545; color: white; }
        .refresh { background: #007bff; color: white; }
        .login { background: #007bff; color: white; }
        .logout { background: #6c757d; color: white; }
        .info { margin: 20px 0; padding: 15px; background: #e9ecef; border-radius: 5px; }
        .login-form { margin: 20px 0; }
        .login-form input { padding: 10px; margin: 5px; border: 1px solid #ddd; border-radius: 4px; width: 200px; }
        .hidden { display: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AWS EC2 <span onclick="whitelistIP()" style="cursor: pointer;">Controller</span></h1>
        
        <div id="loginSection">
            <div class="login-form">
                <input type="password" id="password" placeholder="Password" />
                <button class="login" onclick="login()">Login</button>
            </div>
        </div>
        
        <div id="controlSection" class="hidden">
            <div id="status" class="status">Loading...</div>
            <div id="info" class="info"></div>
            <div>
                <button class="start" onclick="startInstance()">Start EC2</button>
                <button class="stop" onclick="stopInstance()">Stop EC2</button>
                <button class="refresh" onclick="refreshStatus()">Refresh</button>
                <button class="logout" onclick="logout()">Logout</button>
            </div>
        </div>
    </div>
    <script>
        function getToken() {
            return localStorage.getItem('auth_token');
        }
        
        function setToken(token) {
            localStorage.setItem('auth_token', token);
        }
        
        function clearToken() {
            localStorage.removeItem('auth_token');
        }
        
        function checkAuth() {
            const token = getToken();
            if (token) {
                document.getElementById('loginSection').classList.add('hidden');
                document.getElementById('controlSection').classList.remove('hidden');
                refreshStatus();
                setInterval(refreshStatus, 10000);
            } else {
                document.getElementById('loginSection').classList.remove('hidden');
                document.getElementById('controlSection').classList.add('hidden');
            }
        }
        
        async function login() {
            const password = document.getElementById('password').value;
            
            try {
                const response = await fetch('/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password })
                });
                
                const data = await response.json();
                console.log('Login response:', data);
                
                if (response.ok && data.token) {
                    setToken(data.token);
                    console.log('Token stored:', getToken());
                    checkAuth();
                } else {
                    alert('Login failed: ' + (data.error || 'Unknown error'));
                }
            } catch (error) {
                console.error('Login error:', error);
                alert('Login failed');
            }
        }
        
        function logout() {
            clearToken();
            checkAuth();
        }
        
        async function apiCall(path, method = 'GET') {
            const token = getToken();
            console.log('Making API call to:', path, 'with token:', token ? 'present' : 'missing');
            
            const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
            console.log('Headers:', headers);
            
            const response = await fetch(path, { 
                method,
                headers
            });
            
            if (response.status === 401) {
                logout();
                return null;
            }
            
            return response.json();
        }
        
        async function refreshStatus() {
            try {
                const data = await apiCall('/status');
                if (!data) return;
                const statusDiv = document.getElementById('status');
                const infoDiv = document.getElementById('info');
                statusDiv.textContent = `Status: ${data.state.toUpperCase()}`;
                statusDiv.className = `status ${data.state === 'running' ? 'running' : data.state === 'stopped' ? 'stopped' : 'pending'}`;
                infoDiv.innerHTML = `<strong>ID:</strong> ${data.id}<br><strong>IP:</strong> ${data.ip}`;
            } catch (error) {
                document.getElementById('status').textContent = 'Connection error';
            }
        }
        
        async function startInstance() {
            await apiCall('/start', 'POST');
            setTimeout(refreshStatus, 2000);
        }
        
        async function stopInstance() {
            await apiCall('/stop', 'POST');
            setTimeout(refreshStatus, 2000);
        }
        
        async function whitelistIP() {
            console.log('Starting IP whitelist process...');
            
            try {
                console.log('Fetching public IP from ipify...');
                const ipResponse = await fetch('https://api.ipify.org/?format=json');
                const ipData = await ipResponse.json();
                const ip = ipData.ip;
                console.log('Detected IP:', ip);
                
                console.log('Sending whitelist request to lambda...');
                const url = `/allow?ip=${ip}`;
                console.log('Request URL:', url);
                const response = await fetch(url);
                console.log('Response status:', response.status);
                const data = await response.json();
                console.log('Lambda response:', JSON.stringify(data, null, 2));
                
                if (response.ok) {
                    console.log('IP whitelist successful');
                    alert(`IP ${ip} has been whitelisted!`);
                } else {
                    console.error('IP whitelist failed:', data.error);
                    console.error('Debug info:', data.debug);
                    alert('Failed to whitelist IP: ' + data.error + ' (check console for details)');
                }
            } catch (error) {
                console.error('Error in whitelist process:', error);
                alert('Error whitelisting IP');
            }
        }
        
        checkAuth();
    </script>
</body>
</html>'''
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html',
                'Access-Control-Allow-Origin': '*'
            },
            'body': html
        }
    
    # Hidden IP whitelist endpoint
    if method == 'GET' and path.startswith('/allow'):
        try:
            query_params = event.get('queryStringParameters') or {}
            ip_address = query_params.get('ip')
            
            debug_info = {
                'query_params': query_params,
                'ip_address': ip_address,
                'path': path,
                'method': method
            }
            
            if ip_address:
                result = add_ip_to_sg(ip_address)
                debug_info['add_result'] = result
                
                if result.get('success'):
                    return {
                        'statusCode': 200,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({'message': f'IP {ip_address} added to security group', 'debug': debug_info})
                    }
            
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Failed to add IP or missing IP parameter', 'debug': debug_info})
            }
        except Exception as e:
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': str(e), 'debug': debug_info if 'debug_info' in locals() else {}})
            }
    
    # Handle login endpoint (no auth required)
    if method == 'POST' and path == '/login':
        try:
            body = json.loads(event.get('body', '{}'))
            password = body.get('password')
            
            if verify_password(password):
                token = generate_token()
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
                        'Access-Control-Allow-Credentials': 'true'
                    },
                    'body': json.dumps({'token': token, 'debug': 'login_success'})
                }
            else:
                return {
                    'statusCode': 401,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'error': 'Invalid credentials', 'debug': f'pass_len={len(password) if password else 0}'})
                }
        except:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Invalid request'})
            }
    
    # Test endpoint (no auth required)
    if method == 'GET' and path == '/test':
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'message': 'Lambda is working', 'method': method, 'path': path})
        }
    
    # Debug headers endpoint
    if method == 'GET' and path == '/debug':
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'headers': event.get('headers', {}), 'method': method, 'path': path})
        }
    
    # Require token authentication for all other endpoints
    token = get_token_from_header(event)
    if not token or not verify_token(token):
        # Debug info
        debug_info = {
            'error': 'Authentication required',
            'debug': {
                'auth_header': event.get('headers', {}).get('authorization', 'none'),
                'token_found': bool(token),
                'token_valid': verify_token(token) if token else False
            }
        }
        return {
            'statusCode': 401,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(debug_info)
        }
    

    
    if method == 'GET' and path == '/status':
        instance = get_instance_info()
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps(instance)
        }
    
    if method == 'POST' and path == '/start':
        instance = get_instance_info()
        if instance:
            ec2.start_instances(InstanceIds=[instance['id']])
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'message': 'Starting'})
            }
    
    if method == 'POST' and path == '/stop':
        instance = get_instance_info()
        if instance:
            ec2.stop_instances(InstanceIds=[instance['id']])
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'message': 'Stopping'})
            }
    
    return {
        'statusCode': 404,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        'body': json.dumps({'error': 'Not found'})
    }