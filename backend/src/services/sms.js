// SMS Service - Sends invite links to members
// Currently logs to console. Replace with Termii, Africa's Talking, or Twilio

async function sendInviteSMS(phone, message) {
  // TODO: Integrate with SMS provider (Termii recommended for Nigeria)
  // Example Termii integration:
  //
  // const response = await fetch('https://api.ng.termii.com/api/sms/send', {
  //   method: 'POST',
  //   headers: { 'Content-Type': 'application/json' },
  //   body: JSON.stringify({
  //     to: phone,
  //     from: 'AjoSave',
  //     sms: message,
  //     type: 'plain',
  //     channel: 'generic',
  //     api_key: process.env.TERMII_API_KEY,
  //   })
  // });

  console.log(`[SMS] To: ${phone}`);
  console.log(`[SMS] Message: ${message}`);
  console.log('---');

  return { success: true, phone };
}

module.exports = { sendInviteSMS };
