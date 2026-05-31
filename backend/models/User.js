const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
    name: { type: String, required: true },
    username: { type: String, required: true, unique: true },
    email: { type: String, unique: true },
    password: { type: String, required: true },
    role: { type: String, enum: ['ADMIN', 'TEACHER', 'STUDENT'], required: true },
    status: { type: String, enum: ['UNVERIFIED', 'ACTIVE'], default: 'UNVERIFIED' },
    idNumber: String,
    firebaseUid: String,

    // Teacher specific fields
    subjects: [String],

    // Student specific fields
    grade: String,
    strand: String,
    section: String,
    assignedSubject: String,
    professor: String,
    assignedTime: String,
    academicYear: String,

    // Device limit — stores up to 2 registered device IDs per account
    devices: { type: [String], default: [] },
    deviceVerificationCode: String,
    verificationCodeExpiresAt: Date,
    pendingDeviceId: String,
    pendingDevicePlatform: String,
    deviceHistory: [
        {
            oldDeviceId: String,
            newDeviceId: String,
            changedAt: Date,
            actor: String,
            reason: String,
        }
    ],

    createdAt: { type: Date, default: Date.now }
});

// Hash password before saving
userSchema.pre('save', async function() {
    if (!this.isModified('password')) return;
    this.password = await bcrypt.hash(this.password, 10);
});

// Method to compare passwords
userSchema.methods.comparePassword = async function(candidatePassword) {
    return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
