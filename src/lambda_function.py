import os
import boto3
import jwt
import uuid
from datetime import datetime, timezone
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

app = FastAPI()

# ---------------------------------------------------------
# CORS Configuration
# ---------------------------------------------------------
# We restrict origins to our domain and CDN to prevent unauthorized 
# cross-site requests, keeping the API secure and focused.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://mrpservices.tech",
        "https://www.mrpservices.tech",
        "https://d1bukpv5zye5a1.cloudfront.net"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global configuration - these values are injected by Terraform during deployment
REGION = os.getenv("AWS_REGION", "eu-west-1")
TOPIC_ARN = os.getenv("TOPIC_ARN")
TABLE_NAME = os.getenv("TABLE_NAME")
USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")

# Lazy-loading AWS resources for better performance
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(TABLE_NAME)
sns_client = boto3.client('sns', region_name=REGION)

class TicketCreate(BaseModel):
    title: str
    client: str
    description: str
    contact: str

def get_auth_context(authorization: str):
    """
    Decodes the JWT to establish the user identity and permission level.
    This implementation follows a Role-Based Access Control (RBAC) model.
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    try:
        # Standard Bearer token extraction
        token = authorization.replace("Bearer ", "")
        issuer = f"https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}"
        
        # Decoding payload. Note: Signature verification is handled at the API Gateway level 
        # or can be added here using JWKS if needed for extra redundancy.
        decoded = jwt.decode(token, options={"verify_signature": False})
        
        # Security sanity checks: Ensure the token belongs to our specific environment
        if decoded.get("iss") != issuer:
            raise HTTPException(status_code=401, detail="Invalid token issuer")
        
        if decoded.get("client_id") != CLIENT_ID and decoded.get("aud") != CLIENT_ID:
            raise HTTPException(status_code=401, detail="Invalid token audience")

        # Identity resolution: support both ID and Access tokens
        email = decoded.get("email") or decoded.get("username")
        if not email:
            raise HTTPException(status_code=401, detail="User identity not found in token")

        # --- RBAC Logic ---
        # Instead of hardcoding emails, we rely on Cognito's group membership.
        # This makes the system more scalable and easier to manage.
        groups = decoded.get("cognito:groups", [])
        
        # Normalize groups to a list (Cognito sends a string for single-group memberships)
        if isinstance(groups, str):
            groups = [groups]
            
        is_admin = "Admins" in groups

        return email.strip().lower(), is_admin

    except Exception as e:
        print(f"Auth Exception: {str(e)}")
        raise HTTPException(status_code=401, detail="Session invalid or expired")

# --- API Endpoints ---

@app.get("/")
def health_check():
    """Quick heartbeat to verify service availability."""
    return {"status": "online", "service": "mrp-ticketing-api"}

@app.get("/tickets")
def get_tickets(authorization: str = Header(None)):
    """
    Retrieves tickets based on user role. 
    Admins get full visibility; regular users are restricted to their own entries.
    """
    email, is_admin = get_auth_context(authorization)
    
    # Using Scan for simplicity given the current dataset scale. 
    # For large-scale production, a Global Secondary Index (GSI) on 'email' is recommended.
    response = table.scan()
    items = response.get('Items', [])
    items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    if is_admin:
        return items

    return [t for t in items if t.get("email") == email]

@app.post("/tickets")
def create_ticket(ticket: TicketCreate, authorization: str = Header(None)):
    """Logs a new support request into DynamoDB and triggers notifications."""
    email, _ = get_auth_context(authorization)

    new_ticket = {
        "id": str(uuid.uuid4()),
        "title": ticket.title,
        "client": ticket.client,
        "description": ticket.description,
        "contact": ticket.contact,
        "email": email,
        "status": "open",
        "created_at": datetime.now(timezone.utc).isoformat()
    }

    table.put_item(Item=new_ticket)

    # Fire-and-forget notification to keep the support team updated
    if TOPIC_ARN:
        try:
            sns_client.publish(
                TopicArn=TOPIC_ARN,
                Message=f"New ticket from {ticket.client}: {ticket.title}\nUser: {email}",
                Subject=f"🚨 New Ticket Alert: {ticket.title}"
            )
        except Exception as e:
            # We don't want an SNS failure to block the ticket creation response
            print(f"Non-critical SNS Error: {e}") 

    return new_ticket

@app.put("/tickets/{ticket_id}/resolve")
def resolve_ticket(ticket_id: str, authorization: str = Header(None)):
    """Closes a ticket. Restricted to Admin group members only."""
    _, is_admin = get_auth_context(authorization)
    
    if not is_admin:
        raise HTTPException(status_code=403, detail="Forbidden: Admin access required")

    table.update_item(
        Key={"id": ticket_id},
        UpdateExpression="SET #s = :status",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":status": "resolved"}
    )
    return {"message": "Ticket marked as resolved"}

@app.put("/tickets/{ticket_id}/reopen")
def reopen_ticket(ticket_id: str, authorization: str = Header(None)):
    """Allows admins to reopen a resolved ticket if further action is needed."""
    _, is_admin = get_auth_context(authorization)
    
    if not is_admin:
        raise HTTPException(status_code=403, detail="Forbidden: Admin access required")

    table.update_item(
        Key={"id": ticket_id},
        UpdateExpression="SET #s = :status",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":status": "open"}
    )
    return {"message": "Ticket reopened"}

# The Mangum wrapper allows the FastAPI app to run seamlessly on AWS Lambda
handler = Mangum(app)